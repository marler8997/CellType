# CellType

Highly configurable, programmatic, GPU-friendly text rendering.

## Overview

CellType is a new font technology that reimagines how digital fonts are defined and rendered. Unlike traditional font formats that rely on fixed outlines, CellType uses a dynamic approach that enables runtime configuration of font properties like weight/alignment/position while maintaining crisp rendering of straight lines.

## Key Features

- renderable at any size
- renderable at any weight
- named coordinate system
- crisp stright lines (no antialiasing for vertical/horizontal lines)
- stroke-based primitives
- GPU-renderable

# Sample

<p align="center">
  <img src="https://github.com/user-attachments/assets/0fc654c5-4e58-4211-8869-5ab652fb7457" alt="Example" width="751" height="833" />
</p>

## Named Coordinate System

Traditional font technologies like TrueType use a fixed design coordinate system where glyph points are positioned using absolute values. CellType replaces this with a named coordinate system. Instead of fixed values, positions are defined using semantic names like "baseline_stroke". These named coordinates can be dynamically mapped to different pixel values at runtime, enabling flexible font adjustment.

## Stroke-Based Primitives

While traditional fonts define characters using outline points, CellType is configured at a higher level using stroke-based properties. This approach allows a single font definition to support any stroke width without requiring redefinition of the primitives or multiple font files.
