import sys
import re
def convert_regex_to_python(regex_pattern):
    """
    Convert PCRE/Java-style regex to Python-compatible regex
    """
    converted = regex_pattern
    converted = converted.replace("\\K", "")
    converted = converted.replace("\\R", "(?:\\r\\n|\\n|\\r)")
    converted = converted.replace("\\h", "[ \\t]")
    converted = converted.replace("\\v", "[\\n\\r\\f\\v]")
    return converted
def process_regex_file(input_file):
    """
    Read CSV file with regex patterns and extract regexes
    """
    regexes = []
    with open(input_file, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            parts = line.split(",", 3)
            if len(parts) >= 4:
                regex_pattern = parts[3]
                converted_regex = convert_regex_to_python(regex_pattern)
                regexes.append(converted_regex)
                print(f"Processed line {line_num}: ID {parts[0]}")
            else:
                print(f"Warning: Line {line_num} doesn't match expected format, skipping")
    return regexes
def save_as_python_module(regexes, output_file):
    """
    Save regexes as a Python file with a list
    """
    with open(output_file, "w", encoding="utf-8") as f:
        f.write("# Auto-generated regex patterns\n")
        f.write("# Generated from CSV file\n\n")
        f.write("import re\n\n")
        f.write("REGEX_PATTERNS = [\n")
        for regex in regexes:
            escaped_regex = regex.replace('"""', '\\"\\"\\"')
            f.write(f'    r"""{escaped_regex}""",\n')
        f.write("]\n\n")
        f.write("# Optional: Pre-compile patterns for better performance\n")
        f.write("COMPILED_PATTERNS = [re.compile(pattern) for pattern in REGEX_PATTERNS]\n")
    print(f"\nSaved {len(regexes)} regex patterns to {output_file}")
def main():
    if len(sys.argv) != 2:
        print("Usage: python script.py <input_csv_file>")
        sys.exit(1)
    input_file = sys.argv[1]
    output_file = input_file.rsplit(".", 1)[0] + "_regexes.py"
    print(f"Processing {input_file}...")
    regexes = process_regex_file(input_file)
    if regexes:
        save_as_python_module(regexes, output_file)
        print(f"Done! Output saved to {output_file}")
    else:
        print("No regex patterns found in file")
if __name__ == "__main__":
    main()
