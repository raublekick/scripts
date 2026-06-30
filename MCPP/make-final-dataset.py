import sys
import argparse
import csv
import re

parser = argparse.ArgumentParser(description='Convert plant guide data to a different format.')
parser.add_argument('pollinator_file', type=str, help='Path to the input pollinator plant file')
parser.add_argument('host_plant_file', type=str, help='Path to the input host plant file')
parser.add_argument('output_file', type=str, help='Path to the output file where converted')
if len(sys.argv)==1:
    parser.print_help(sys.stderr)
    sys.exit(1)
args = parser.parse_args()

def find_host_match(plant: dict, hosts: list[dict]) -> tuple:
    for index, host in enumerate(hosts):
        if host['Common Name'] == plant['Common Name'] and host['Scientific Name'] == plant['Scientific Name'] and host['Type'] == plant['Type']:
            weight = 3
            # print("Found:", index, weight, host['Host For']`)
            return(index, weight, host['Host For'])
        elif host['Scientific Name'] == plant['Scientific Name'] and host['Type'] == plant['Type']:
            weight = 2
            # print ("Found:", index, weight, host['Host For'])
            return(index, weight, host['Host For'])
        elif host['Common Name'] == plant['Common Name'] and host['Type'] == plant['Type']:
            weight = 1
            # print("Found:", index, weight, host['Host For'])
            return(index, weight, host['Host For'])
        
    return (None, 0)

def find_plant_match(host: dict, plants: list[dict]) -> bool:
    for index, plant in enumerate(plants):
        if host['Common Name'] == plant['Common Name'] and host['Scientific Name'] == plant['Scientific Name'] and host['Type'] == plant['Type']:
            return True
        elif host['Scientific Name'] == plant['Scientific Name'] and host['Type'] == plant['Type']:
            return True
        elif host['Common Name'] == plant['Common Name'] and host['Type'] == plant['Type']:
            return True
        
    return False

host_rows = []
with open(args.host_plant_file, 'r') as f:
    host_data = csv.DictReader(f)
    for host in host_data:
       host_rows.append(host)

new_rows = []
# iterate pollinator file and find matches from hosts
with open(args.pollinator_file, 'r') as f:
    data = csv.DictReader(f)
    for index, row in enumerate(data):
        new_row = row
        new_row['Source'] = 'MCPP'
        new_row['Pollinator'] = True

        host_match = find_host_match(row, host_rows)
        # if there is a match, set the host plant flag, weight, and host for
        if host_match[0] != None:
            row['Host Plant'] = True
            row['Host Plant Weight'] = host_match[1]
            row['Host For'] = host_match[2]
            print("Match found:", host_match)
        # if no match but the plant guide was marked as a host, keep the host flag
        elif new_row['Host Plant'] == 'TRUE': 
            row['Host For'] = ''
            row['Host Plant Weight'] = None
        # else just make sure the fields are initialized
        else:
            row['Host Plant'] = ''
            row['Host For'] = ''
            row['Host Plant Weight'] = None

        new_rows.append(new_row)

# iterate the hosts file again, and any unmatched entries add to the master list
for index, host in enumerate(host_rows):
    matched = find_plant_match(host, new_rows)
    if not matched:
        new_row = dict()
        new_row['Common Name'] = host['Common Name']
        new_row['Scientific Name'] = host['Scientific Name']
        new_row['Type'] = host['Type']
        new_row['Source'] = 'MCPPH'
        new_row['Host Plant'] = True
        new_row['Host For'] = host['Host For']
        new_rows.append(new_row)
        print("Added host: ", new_row)

# output new_rows as CSV to output file
with open(args.output_file, 'w', newline='') as csvfile:
    fields = new_rows[0].keys()
    print('Creating new CSV file with headers: ', fields)

    writer = csv.DictWriter(csvfile, fieldnames=fields)

    writer.writeheader()
    for row in new_rows:
        writer.writerow(row)
    print('Done!')