#!/usr/bin/env python3
"""Remove orphaned duplicate lines 12113-12119 from lib/main.dart"""
import os

path = os.path.join(os.path.dirname(__file__), 'lib', 'main.dart')

with open(path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Verify the lines to delete contain what we expect
target_start = 12112  # 0-indexed = line 12113
target_end = 12119    # exclusive = through line 12119

# Print what we're about to delete
print("Lines to delete:")
for i in range(target_start, target_end):
    print(f"  {i+1}: {lines[i].rstrip()}")

# Safety check: the line after the block should be "  String _sectionTitle"
if '_sectionTitle' not in lines[target_start]:
    print(f"ERROR: Expected _sectionTitle at line {target_start+1}, got: {lines[target_start].rstrip()}")
    exit(1)

# Delete the lines
del lines[target_start:target_end]

with open(path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\nDone: removed {target_end - target_start} lines")
print("\nVerification (lines around edit point):")
with open(path, 'r', encoding='utf-8') as f:
    verify = f.readlines()
for i in range(target_start - 3, target_start + 5):
    print(f"  {i+1}: {verify[i].rstrip()}")
