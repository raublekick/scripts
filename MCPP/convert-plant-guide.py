import sys
import argparse
import csv
import re

parser = argparse.ArgumentParser(description='Convert plant guide data to a different format.')
parser.add_argument('pollinator_file', type=str, help='Path to the input pollinator plant file')
# parser.add_argument('host_plant_file', type=str, help='Path to the input host plant file')
parser.add_argument('output_file', type=str, help='Path to the output file where converted')
if len(sys.argv)==1:
    parser.print_help(sys.stderr)
    sys.exit(1)
args = parser.parse_args()

codes = [
    { 'code': 'HUM', 'name': 'Hummingbird Attractor' },
    { 'code': 'HOST', 'name': 'Host Plant' },
    { 'code': 'MNSL', 'name': 'Maricopa Native Seed Library' },
    { 'code': 'POTS', 'name': 'Container Friendly' },
    { 'code': 'BRDNST', 'name': 'Bird Nest Habitat' },
    { 'code': 'SPCVAL', 'name': 'Special Value Native Bees' },
    { 'code': 'BloomExt', 'name': 'Extended Bloom' },
]

# remove newlines and arbitrary spaces
def clean_string(x:str) -> str:
    cleaned_string = x.replace('\n', ' ').replace('/ ', '/')
    return cleaned_string

def find_host_match(plant: dict, hosts: list[dict]) -> tuple:
    for index, host in enumerate(hosts):
        if host['Common Name'] == plant['Common Name'] and host['Scientific Name'] == plant['Scientific Name'] and host['Type'] == plant['Type']:
            weight = 3
            print("Found:", index, weight)
            return(index, weight)
        elif host['Scientific Name'] == plant['Scientific Name'] and host['Type'] == plant['Type']:
            weight = 2
            return(index, weight)
        elif host['Common Name'] == plant['Common Name'] and host['Type'] == plant['Type']:
            weight = 1
            return(index, weight)
        
    return (None, 0)

# host_rows = []
# with open(args.host_plant_file, 'r') as f:
#     host_data = csv.DictReader(f)
#     for host in host_data:
#        host_rows.append(host)

new_rows = []
# iterate input file and clean rows
with open(args.pollinator_file, 'r') as f:
    data = csv.DictReader(f)
    for index, row in enumerate(data):
        new_row = row
        new_row['Common Name'] = clean_string(row['Common Name'])
        new_row['Scientific Name'] = clean_string(row['Scientific Name'])
        cleaned_note = clean_string(row['Notes'])
        # print(cleaned_note)
        for code in codes:
            if code['code'] in cleaned_note:
                # update the row value and remove from note
                row[code['name']] = 'TRUE'
                reg = re.compile(code['code'] + '[.;,]*')
                cleaned_note = reg.sub('', cleaned_note)
            else:
                row[code['name']] = ''
        cleaned_note = cleaned_note.strip()
        if cleaned_note.endswith(",") or cleaned_note.endswith('.'):
            cleaned_note = cleaned_note[:-1] + ''
        row['Notes'] = cleaned_note

        # host_match = find_host_match(row, host_rows)
        # if host_match[0] != None:
        #     row['Host Plant'] = True
        #     row['Host Plant Weight'] = host_match[1]
        #     print("Match found:", host_match)
        # else: 
        #     row['Host Plant'] = False
        #     row['Host Plant Weight'] = None

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