# The PhaseTree: Multiphase Signed Distance Fields 

This repository contains the source code of the ACM TOG / SIGGRAPH 2026 paper *"[The PhaseTree: Multiphase Signed Distance Fields](https://perso.liris.cnrs.fr/eric.galin/Articles/2026-phasetree.pdf)", 
Eric Galin, Pierre Hubert-Brierre, Hugo Schott, Marie-Paule Cani, Adrien Peytavie, Eric Guérin*

## Fundamentals

The [MultiPhase](GLSL/multiphase.glsl) code implements multiphase primitives, internal and hybrid operators.
The [Void](GLSL/void.glsl) model simply defines a sphere with a one phase. 
The purpose of this example is to show a fast rendering setup for other models.

Objects should be defined as functions vec4 Object(in vec3 p) returning a vec4 containing the phase values. 

## Multiphase example models

A typical example is the [Hourglass](GLSL/hourglass.glsl) that implements some multiphase operators and primitives needed for modeling the shape.

## Requirements

We provide a simple GLSL implementation of some examples, directly renderable using [Visual Studio Code](https://code.visualstudio.com/) using the [ShaderToy](https://marketplace.visualstudio.com/items?itemName=stevensona.shader-toy) extension.

## License

See [LICENSE](LICENSE) for details on the license of this project.