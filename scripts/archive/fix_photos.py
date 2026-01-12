#!/usr/bin/env python3
import sys

# Lire le fichier
with open('lib/main.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Trouver et remplacer
found_start = False
start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if 'Photos de' in line and 'annonce' in line and not found_start:
        # Backtrack pour trouver le SizedBox(height: 20) avant
        for j in range(i-1, max(0, i-10), -1):
            if 'SizedBox(height: 20)' in lines[j]:
                start_idx = j
                break
        found_start = True
    
    if found_start and 'SizedBox(height: 22)' in line and 'Photos' in ''.join(lines[max(0,start_idx):i+1]):
        end_idx = i
        break

if start_idx >= 0 and end_idx >= 0:
    print(f"Found section from line {start_idx+1} to {end_idx+1}")
    
    # Extract the old section
    old_lines = lines[start_idx:end_idx+1]
    
    # Create new lines with the if condition
    new_lines = [
        "                          const SizedBox(height: 20),\n",
        "\n",
        "                          // ✅ Si photos, on les affiche ; sinon, on affiche une grande pub\n",
        "                          if (photos.isNotEmpty) ...[",
        "                            const Text(\n",
        "                              \"Photos de l'annonce\",\n",
        "                              style: TextStyle(\n",
        "                                fontSize: 16,\n",
        "                                fontWeight: FontWeight.w700,\n",
        "                              ),\n",
        "                            ),\n",
        "                            const SizedBox(height: 10),\n",
        "                            SizedBox(\n",
        "                              height: 190,\n",
        "                              child: Row(\n",
        "                                children: [\n",
        "                                  Expanded(\n",
        "                                    child: _buildPhotoTile(\n",
        "                                      url: photos.isNotEmpty ? photos[0] : null,\n",
        "                                      primary: true,\n",
        "                                    ),\n",
        "                                  ),\n",
        "                                  const SizedBox(width: 10),\n",
        "                                  Expanded(\n",
        "                                    child: _buildPhotoTile(\n",
        "                                      url: photos.length > 1 ? photos[1] : null,\n",
        "                                      primary: false,\n",
        "                                    ),\n",
        "                                  ),\n",
        "                                ],\n",
        "                              ),\n",
        "                            ),\n",
        "                            const SizedBox(height: 22),\n",
        "                          ],\n",
    ]
    
    # Replace
    lines = lines[:start_idx] + new_lines + lines[end_idx+1:]
    
    # Write back
    with open('lib/main.dart', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    print("✅ Section photos remplacée!")
else:
    print(f"❌ Section non trouvée (start={start_idx}, end={end_idx})")
