#!/usr/bin/env python3
import os
import json
import subprocess
from eth_utils import keccak, to_hex

def compute_selector(signature):
    """
    Computes the selector (first 4 bytes of the keccak256 hash)
    for a given error signature.
    """
    return to_hex(keccak(text=signature))[:10]

def process_ast_node(node):
    """
    Recursively traverses the AST to extract custom error signatures.
    It looks for nodes with "nodeType" equal to "ErrorDefinition".
    """
    if isinstance(node, dict):
        if node.get("nodeType") == "ErrorDefinition":
            name = node.get("name")
            params = []
            if "parameters" in node and "parameters" in node["parameters"]:
                for param in node["parameters"]["parameters"]:
                    param_type = param.get("typeDescriptions", {}).get("typeString")
                    params.append(param_type)
            signature = f"{name}({','.join(params)})"
            yield signature
        for value in node.values():
            if isinstance(value, dict):
                yield from process_ast_node(value)
            elif isinstance(value, list):
                for item in value:
                    yield from process_ast_node(item)

def forge_build_ast():
    """
    Runs the command "forge build --ast" to compile the contracts and generate the artifacts in the "out/" directory.
    """
    print("Running 'forge build --ast' ...")
    result = subprocess.run(["forge", "build", "--ast"], capture_output=True, text=True)
    if result.returncode != 0:
        print("Error during 'forge build':", result.stderr)
        return False
    print("Forge build completed successfully.")
    return True

def load_ast_from_out(directory="out"):
    """
    Recursively searches the 'out' directory for JSON files containing an AST.
    Returns a dictionary where keys are file paths and values are the AST objects.
    """
    asts = {}
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".json"):
                path = os.path.join(root, file)
                with open(path, "r") as f:
                    try:
                        data = json.load(f)
                    except Exception as e:
                        print(f"Error reading {path}: {e}")
                        continue
                    if "ast" in data:
                        asts[path] = data["ast"]
    return asts

def write_markdown_output(results, output_file="errorSignature.md"):
    """
    Writes the results into a Markdown file with a neat format.
    """
    with open(output_file, "w") as f:
        f.write("# Custom Error Selectors\n\n")
        if not results:
            f.write("No custom errors found in the contracts.\n")
            return

        for filepath, errors in results.items():
            f.write(f"## File: `{filepath}`\n\n")
            for sig, selector in errors.items():
                f.write(f"- **{sig}** → `{selector}`\n")
            f.write("\n")
    print(f"Results written to {output_file}")

def main():
    # Run "forge build --ast" to compile the contracts and generate AST artifacts
    if not forge_build_ast():
        return

    # Load ASTs from the "out" directory
    asts = load_ast_from_out("out")
    if not asts:
        print("No AST files found in the 'out' directory.")
        return

    all_errors = {}
    # Traverse each AST and extract custom error definitions
    for filepath, ast in asts.items():
        errors_found = {}
        for signature in process_ast_node(ast):
            try:
                selector = compute_selector(signature)
            except Exception as e:
                print(f"Error computing selector for {signature} in {filepath}: {e}")
                continue
            errors_found[signature] = selector
        if errors_found:
            all_errors[filepath] = errors_found

    # Write the results to a Markdown file
    write_markdown_output(all_errors)

if __name__ == "__main__":
    main()
