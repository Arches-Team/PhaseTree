// BlobTree model
// The functions return both the potential field and the distance to the compact support

// The body is skipped when the code is compiled as GLSL ES 1.00, i.e., when the VS Code shader-toy extension test compiles this file on its own
#if !defined(BLOBTREE_GLSL) && __VERSION__ >= 300
#define BLOBTREE_GLSL

// Threshold
const float T = 0.5;

// Smooth cubic falloff function
// x : Distance
// R : Radius
float Falloff(float x, float R) {
  float u = clamp(x / R, 0.0, 1.0);
  float v = (1.0 - u * u);
  return v * v * v;
}

// Primitives

// Point skeleton
// p : Point
// c : Center of skeleton
// e : Energy associated to skeleton
// R : Radius
vec2 Point(vec3 p, vec3 c, float e, float R) {
  return vec2(e * Falloff(length(p - c), R), length(p - c) - R);
}

// Operators

// Blending
// a, b : Field functions of the sub-trees
vec2 Blend(vec2 a, vec2 b) {
  return vec2(a.x + b.x, min(a.y, b.y));
}

// Convert BlobTree field function to signed distance field
// v : Field value minus the threshold, and distance to the compact support
// k : Lipschitz constant of the BlobTree
float BlobToSdf(vec2 v, float k) {
  if(v.y < 0.0) {
    return -v.x / k;
  }

  return T / k + v.y;
}

#endif
