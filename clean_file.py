#!/usr/bin/env python3
# Read the malformed file
with open('/workspaces/presto_app/lib/main.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find and delete orphaned code between Container decoration and child: SafeArea
# The orphaned code starts around line 5525 (index 5524) and contains weird code
# We need to find the line with "decoration: BoxDecoration(" and skip all the bad code
# until we reach "color: Colors.white,"

output = []
skip_until_white = False
i = 0

while i < len(lines):
    line = lines[i]
    
    # Check if this is the problematic "decoration: BoxDecoration(" line
    if 'decoration: BoxDecoration(' in line and skip_until_white == False:
        # Check if the next line has the wrong content (borderRadius instead of color)
        if i + 1 < len(lines) and 'borderRadius' in lines[i+1]:
            output.append(line)
            output.append('                color: Colors.white,\n')
            output.append('                boxShadow: [\n')
            output.append('                  BoxShadow(\n')
            output.append('                    color: Colors.black.withOpacity(0.08),\n')
            output.append('                    blurRadius: 14,\n')
            output.append('                    offset: const Offset(0, -4),\n')
            output.append('                  ),\n')
            output.append('                ],\n')
            output.append('              ),\n')
            output.append('              child: SafeArea(\n')
            # Now skip all the orphaned code until we find the actual child content
            skip_count = 0
            i += 1
            while i < len(lines):
                if 'child: SafeArea(' in lines[i]:
                    i += 1
                    break
                i += 1
            continue
    
    output.append(line)
    i += 1

# Write back
with open('/workspaces/presto_app/lib/main.dart', 'w', encoding='utf-8') as f:
    f.writelines(output)

print("File cleaned!")
