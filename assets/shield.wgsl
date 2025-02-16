#import bevy_pbr::{
    mesh_view_bindings::{
        globals,
        view
    },
    mesh_bindings::mesh,
    mesh_functions as mesh_functions,
    forward_io::Vertex,
    view_transformations::position_world_to_clip,
}
#import bevy_pbr::prepass_utils::prepass_depth


fn permute_four(x: vec4<f32>) -> vec4<f32> { return ((x * 34. + 1.) * x) % vec4<f32>(289.); }
fn taylor_inv_sqrt_four(r: vec4<f32>) -> vec4<f32> { return 1.79284291400159 - 0.85373472095314 * r; }

fn simplex_noise_3d(v: vec3<f32>) -> f32 {
  let C = vec2<f32>(1. / 6., 1. / 3.);
  let D = vec4<f32>(0., 0.5, 1., 2.);

  // First corner
  var i: vec3<f32>  = floor(v + dot(v, C.yyy));
  let x0 = v - i + dot(i, C.xxx);

  // Other corners
  let g = step(x0.yzx, x0.xyz);
  let l = 1.0 - g;
  let i1 = min(g.xyz, l.zxy);
  let i2 = max(g.xyz, l.zxy);

  // x0 = x0 - 0. + 0. * C
  let x1 = x0 - i1 + 1. * C.xxx;
  let x2 = x0 - i2 + 2. * C.xxx;
  let x3 = x0 - 1. + 3. * C.xxx;

  // Permutations
  i = i % vec3<f32>(289.);
  let p = permute_four(permute_four(permute_four(
      i.z + vec4<f32>(0., i1.z, i2.z, 1. )) +
      i.y + vec4<f32>(0., i1.y, i2.y, 1. )) +
      i.x + vec4<f32>(0., i1.x, i2.x, 1. ));

  // Gradients (NxN points uniformly over a square, mapped onto an octahedron.)
  var n_: f32 = 1. / 7.; // N=7
  let ns = n_ * D.wyz - D.xzx;

  let j = p - 49. * floor(p * ns.z * ns.z); // mod(p, N*N)

  let x_ = floor(j * ns.z);
  let y_ = floor(j - 7.0 * x_); // mod(j, N)

  let x = x_ *ns.x + ns.yyyy;
  let y = y_ *ns.x + ns.yyyy;
  let h = 1.0 - abs(x) - abs(y);

  let b0 = vec4<f32>( x.xy, y.xy );
  let b1 = vec4<f32>( x.zw, y.zw );

  let s0 = floor(b0)*2.0 + 1.0;
  let s1 = floor(b1)*2.0 + 1.0;
  let sh = -step(h, vec4<f32>(0.));

  let a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  let a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  var p0: vec3<f32> = vec3<f32>(a0.xy, h.x);
  var p1: vec3<f32> = vec3<f32>(a0.zw, h.y);
  var p2: vec3<f32> = vec3<f32>(a1.xy, h.z);
  var p3: vec3<f32> = vec3<f32>(a1.zw, h.w);

  // Normalise gradients
  let norm = taylor_inv_sqrt_four(vec4<f32>(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
  p0 = p0 * norm.x;
  p1 = p1 * norm.y;
  p2 = p2 * norm.z;
  p3 = p3 * norm.w;

  // Mix final noise value
  var m: vec4<f32> = 0.6 - vec4<f32>(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3));
  m = max(m, vec4<f32>(0.));
  m = m * m;
  return 42. * dot(m * m, vec4<f32>(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}

// copy from https://github.com/rust-adventure/bevy-examples/blob/3af65d31c9da0b493ff2019dfd05974abd75850f/examples/shield-with-depth/assets/shaders/custom_material.wgsl

// mostly a clone of bevy_pbr::forward_io::VertexOutput
// so that we can add the extra fields
struct VertexOutput {
    // This is `clip position` when the struct is used as a vertex stage output
    // and `frag coord` when used as a fragment stage input
    @builtin(position) position: vec4<f32>,
    @location(0) world_position: vec4<f32>,
    @location(1) world_normal: vec3<f32>,
#ifdef VERTEX_UVS
    @location(2) uv: vec2<f32>,
#endif
#ifdef VERTEX_TANGENTS
    @location(3) world_tangent: vec4<f32>,
#endif
#ifdef VERTEX_COLORS
    @location(4) color: vec4<f32>,
#endif
#ifdef VERTEX_OUTPUT_INSTANCE_INDEX
    @location(5) @interpolate(flat) instance_index: u32,
#endif
    @location(6) position_diff: f32,
};

@vertex
fn vertex(vertex: Vertex) -> VertexOutput {
    let thickness = 0.5;
    let how_long_to_stay_in_opposite_state = 30.0;
    let frequency = 2.0;
    let position_diff = 1.0 - pow(thickness * sin(frequency * globals.time + vertex.position.y + vertex.position.z), how_long_to_stay_in_opposite_state);
    let position = (vertex.normal * (smoothstep(0.0, 1.0, position_diff)) * 0.04) + vertex.position;

    var out: VertexOutput;
    out.position_diff = position_diff;

    var model = mesh_functions::get_model_matrix(vertex.instance_index);
    out.world_normal = mesh_functions::mesh_normal_local_to_world(vertex.normal, vertex.instance_index);

#ifdef VERTEX_POSITIONS
    // out.world_position = mesh_functions::mesh_position_local_to_world(model, vec4<f32>(vertex.position, 1.0));
    out.world_position = mesh_functions::mesh_position_local_to_world(model, vec4<f32>(position, 1.0));
    out.position = position_world_to_clip(out.world_position.xyz);
#endif
#ifdef VERTEX_UVS
    out.uv = vertex.uv;
#endif
#ifdef VERTEX_TANGENTS
    out.world_tangent = mesh_tangent_local_to_world(model, vertex.tangent);
#endif
#ifdef VERTEX_COLORS
    out.color = vertex.color;
#endif
    return out;
}

struct CustomMaterial {
    color: vec4<f32>,
};

@group(1) @binding(0)
var<uniform> material: CustomMaterial;

@fragment
fn fragment(
    @builtin(front_facing) is_front: bool,
    mesh: VertexOutput,
    // @location(6) position_diff: f32,
) -> @location(0) vec4<f32> {
    let V = normalize(view.world_position.xyz - mesh.world_position.xyz);
    var fresnel = 1.0 - dot(mesh.world_normal, V);
    fresnel = pow(fresnel, 5.0);

    var noise = simplex_noise_3d(vec3<f32>(mesh.world_normal.xy * 4.2, globals.time));
    var alpha = (noise + 1.0) / 2.0;

    let highlight = smoothstep(0.0, 1.0, mesh.position_diff + 1.0);

    let offset = 0.82;
    let intersection_intensity = 10.0;
    let depth = prepass_depth(mesh.position, 0u);
    var intersection = 1.0 - ((mesh.position.z - depth) * 100.0) - offset;
    intersection = smoothstep(0.0, 1.0, intersection);
    if is_front {
        intersection *= intersection_intensity;
    } else {
        intersection *= intersection_intensity / 2.0;
    }

    let color = mix(vec3(1.00, 0.455, 0.827), vec3(1.00, 0.555, 0.927), highlight) * (alpha + 0.5) * 5.0;
    if is_front {
        return vec4(color * (10.0 * highlight + 1.0), fresnel * 0.4 + intersection + highlight * 0.003);
    } else {
        return vec4(color, intersection);
    }
}