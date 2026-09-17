"""Authoring-only targeted text edits; never rebuild the existing village."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
village = ROOT / 'village/yao_village.tscn'
collisions = ROOT / 'village/hero/world_collisions.tscn'
text = village.read_text(encoding='utf-8')
physics = collisions.read_text(encoding='utf-8')
assert 'WesternBurialRidge' not in text, 'Already integrated; edit saved scenes directly.'
text = text.replace('[gd_scene format=4]', '[gd_scene format=4]\n\n[ext_resource type="PackedScene" path="res://burial_ridge/world.tscn" id="WesternRidgeScene"]', 1)
text += '\n[node name="WesternBurialRidge" parent="." instance=ExtResource("WesternRidgeScene")]\n\n[editable path="WesternBurialRidge"]\n'
# Relocate only the six trees in the west road opening, retaining every subtree.
destinations = {'BroadleafTree22':(-32,12), 'BroadleafTree23':(-34,13),
                'BroadleafTree24':(-32,16), 'BroadleafTree55':(-29,15),
                'BroadleafTree56':(-30,18), 'BroadleafTree57':(-28,20)}
for name,(x,z) in destinations.items():
    def move(match):
        v = match[2].split(', ')
        v[9],v[11] = str(x),str(z)
        return match[1] + ', '.join(v) + ')'
    pattern = rf'(\[node name="{name}"[^\n]*parent="ForestBoundary"[^\n]*\]\ntransform = Transform3D\()([^)]+)\)'
    text,n = re.subn(pattern,move,text)
    assert n == 1, name
    pattern = rf'(\[node name="{name}_Trunk"[^\n]*\]\ntransform = Transform3D\()([^)]+)\)'
    physics,n = re.subn(pattern,move,physics)
    assert n == 1, name + ' collision'
pattern = r'(\[node name="CollisionShape3D" type="CollisionShape3D" parent="\."[^\n]*\]\n[^\[]*?shape = SubResource\("BoxShape3D_d3bdv"\))'
physics,n = re.subn(pattern,r'\1\ndisabled = true',physics)
assert n == 1
village.write_text(text,encoding='utf-8')
collisions.write_text(physics,encoding='utf-8')
print('Integrated saved WesternBurialRidge; moved six trees and matching collisions; opened former west boundary.')
