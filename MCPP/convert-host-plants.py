import sys
import argparse
import csv
import re

parser = argparse.ArgumentParser(description='Convert plant guide data to a different format.')
parser.add_argument('host_plant_file', type=str, help='Path to the input host plant file')
parser.add_argument('output_file', type=str, help='Path to the output file where converted')
if len(sys.argv)==1:
    parser.print_help(sys.stderr)
    sys.exit(1)
args = parser.parse_args()

# remove newlines and arbitrary spaces
def clean_string(x:str) -> str:
    cleaned_string = x.replace('\n', ' ').replace('/ ', '/')
    return cleaned_string

new_rows = []
# iterate input file and clean rows
with open(args.host_plant_file, 'r') as f:
    data = csv.DictReader(f)
    for index, row in enumerate(data):
        new_row = row
        new_row['Common Name'] = clean_string(row['Common Name'])
        new_row['Scientific Name'] = clean_string(row['Scientific Name'])
        cleaned_note = clean_string(row['Host For'])
        cleaned_note = cleaned_note.strip()
        if cleaned_note.endswith(",") or cleaned_note.endswith('.'):
            cleaned_note = cleaned_note[:-1] + ''
        row['Host For'] = cleaned_note

        # print(index, new_row)
        new_rows.append(new_row)


# output new_rows as CSV to output file
with open(args.output_file, 'w', newline='') as csvfile:
    fields = new_rows[0].keys()
    print('Creating new CSV file with headers: ', fields)

    writer = csv.DictWriter(csvfile, fieldnames=fields)

    writer.writeheader()
    for row in new_rows:
        writer.writerow(row)
    print('Done!')