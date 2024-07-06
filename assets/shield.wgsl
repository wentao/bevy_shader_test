#import bevy_pbr::mesh_functions::{get_model_matrix, mesh_position_local_to_clip}
#import bevy_pbr::mesh_view_bindings::{globals, view}
#import bevy_pbr::forward_io::VertexOutput
#import bevy_pbr::forward_io::Vertex
#import bevy_pbr::mesh_functions
#import bevy_pbr::view_transformations::position_world_to_clip

@vertex
fn vertex(input: Vertex) -> VertexOutput {
    var output : VertexOutput;
    let model_matrix = get_model_matrix(input.instance_index);
    output.world_position = mesh_functions::mesh_position_local_to_world(model_matrix, vec4<f32>(input.position, 1.0));
    output.position = position_world_to_clip(output.world_position.xyz);
    output.world_normal = mesh_functions::mesh_normal_local_to_world(input.normal, input.instance_index);
    output.uv = input.uv;
    return output;
}

@fragment
fn fragment(in: VertexOutput) -> @location(0) vec4<f32> {
    let view_angle = normalize(-in.world_position.xyz);
    let rim_strength = 1.0 - abs(dot(view_angle, in.world_normal));
    let rim_factor = pow(rim_strength, 1.0);
    let rim = vec4(rim_factor, rim_factor, rim_factor, rim_factor);
    return vec4<f32>(rim.xyz, 1.0);
}
