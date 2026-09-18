"""Add one saved north instance without repacking existing editable child overrides."""
from pathlib import Path

project = Path(__file__).resolve().parents[2]
path = project / "village/yao_village.tscn"
text = path.read_text(encoding="utf-8")
if 'id="NorthernRidgeScene"' in text:
    raise SystemExit("Northern scene is already linked; edit the saved scene directly.")
assert (project / "northern_ridge/world.tscn").exists()
anchor = '\n[sub_resource '
offset = text.index(anchor)
text = text[:offset] + '\n[ext_resource type="PackedScene" path="res://northern_ridge/world.tscn" id="NorthernRidgeScene"]\n' + text[offset:]
offset = text.index('\n[editable path=')
text = text[:offset] + '\n[node name="NorthernRidge" parent="." instance=ExtResource("NorthernRidgeScene")]\n' + text[offset:]
text += '\n[editable path="NorthernRidge"]\n'
path.write_text(text, encoding="utf-8", newline="\n")
print("Linked the saved northern extension in the original village entry.")
