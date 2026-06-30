import sys
import argparse
import csv
import json

parser = argparse.ArgumentParser(description='Convert plant guide data to a different format.')
parser.add_argument('input_file', type=str, help='Path to the input file')
parser.add_argument('output_file', type=str, help='Path to the output file where converted')
if len(sys.argv)==1:
    parser.print_help(sys.stderr)
    sys.exit(1)
args = parser.parse_args()

def convert_camel_case(string: str) -> str:
    new_string = string.replace(' ', '')
    first_letter = new_string[0].lower()
    return first_letter + new_string[1:]

data_rows = []
with open(args.input_file, 'r') as f:
    data = csv.DictReader(f)
    # set actual boolean or null values for boolean fields
    for row in data:
        for key in row.keys():
            match row[key].lower():
                case "true":
                    row[key] = True
                case "false":
                    row[key] = False
                case "":
                    row[key] = None
        jsonified = { convert_camel_case(k): v for k, v in row.items() }
        data_rows.append(jsonified)

# output new_rows as CSV to output file
with open(args.output_file, 'w') as jsonfile:
    json.dump(data_rows, jsonfile, indent=4)
    print('Done!')