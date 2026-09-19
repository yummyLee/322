---
name: ai-scene-terrain-designer
description: Design or revise complex environment-only scene and terrain descriptions for AI image generation, especially top-down game maps, caves, villages, wilderness, ruins, interiors, and production areas. Use when Codex needs to write scene art direction or image prompts without plot, dialogue, quests, character actions, gameplay logic, or visible measurement annotations.
---

# AI Scene Terrain Designer

Create production-ready visual descriptions for AI-generated game environments.

## Core rules

- Describe only visible environment, terrain, spatial relationships, materials, lighting, color, atmosphere, and composition unless the user explicitly requests something else.
- Exclude plot, dialogue, quests, lore exposition, character actions, interactions, game states, BGM, scripts, scene-tree nodes, and implementation details.
- Design internally against the intended image resolution, camera, and game scale. Do not expose pixel dimensions, coordinates, tile counts, body units, or repeated numeric measurements in the written scene document or final prompt unless explicitly requested.
- Translate hidden measurements into relative visual language: dominant hall, narrow throat, broad lower terrace, offset entrance, shallow side chamber, deep northern branch, or occupying most of the western region.
- Make the layout substantially complex enough for the intended canvas. Prefer multiple zones, several bends, occluded sightlines, elevation changes, loops, dead ends, side chambers, secondary landmarks, and distinct surface languages.
- Avoid small central islands of content, sparse layouts, rectangular rooms, straight-through corridors, excessive symmetry, and large unstructured empty areas.

## Workflow

1. Inspect the existing scene document and nearby project conventions.
2. Infer the intended canvas scale and camera internally without repeating its numbers in the output.
3. Establish cardinal orientation and a clear hierarchy: one dominant visual center, several medium zones, and smaller transition or dead-end spaces.
4. Build a spatial graph with at least one main route, multiple secondary routes, loops, dead ends, occluded connections, and elevation changes when the environment supports them.
5. Assign each zone a distinctive terrain shape, boundary form, ground material, landmark, and connection pattern.
6. Describe locations using relative placement and adjacency, not explicit coordinates or unit counts.
7. Add material, lighting, palette, composition, and negative constraints that are directly visible in the generated image.
8. End with one consolidated AI image prompt and a short visual acceptance checklist.

## Complexity standard

- Use enough terrain subdivisions to fill the intended image rather than merely lengthening prose.
- Increase complexity spatially: add meaningful branches, layered routes, intermediate spaces, partial overlooks, narrow connectors, terrain transitions, and recognizable dead ends.
- Keep every added area visually and topologically distinct. Do not duplicate similar empty chambers.
- Preserve readable hierarchy. Complexity should create exploration depth without turning the map into undifferentiated noise.

## Output structure

Use the smallest set of sections that covers:

1. Scene positioning and visual identity.
2. Overall terrain topology and orientation.
3. Detailed environment zones and their relative connections.
4. Terrain surfaces, materials, lighting, and color.
5. Composition and negative visual constraints.
6. A consolidated AI image-generation prompt.
7. A visual acceptance checklist.

Do not add explicit measurement tables, gameplay sections, narrative beats, interaction lists, implementation suggestions, or technical scene-tree structures unless requested.
