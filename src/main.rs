use std::f32::consts::PI;

use bevy::core::FrameCount;
use bevy::core_pipeline::bloom::BloomSettings;
use bevy::core_pipeline::prepass::DepthPrepass;
use bevy::core_pipeline::tonemapping::Tonemapping;
use bevy::ecs::system::Command;
use bevy::log::LogPlugin;
use bevy::pbr::NotShadowCaster;
use bevy::prelude::*;
use bevy::render::camera::Exposure;
use bevy::window::*;
use itertools::Itertools;
use shield::ShieldMaterial;

mod shield;

fn main() {
    App::new()
        .add_plugins((
            DefaultPlugins
                .set(WindowPlugin {
                    primary_window: Some(Window {
                        title: "Scene Viewer".into(),
                        resolution: (450., 800.).into(),
                        resizable: false,
                        window_theme: Some(WindowTheme::Dark),
                        present_mode: PresentMode::AutoVsync,
                        enabled_buttons: EnabledButtons {
                            minimize: false,
                            maximize: false,
                            ..Default::default()
                        },
                        // This will spawn an invisible window
                        // The window will be made visible in the make_visible() system after 3 frames.
                        // This is useful when you want to avoid the white window that shows up before the GPU is ready to render the app.
                        visible: false,
                        ..default()
                    }),
                    ..default()
                })
                .set(LogPlugin {
                    update_subscriber: None,
                    filter: "info,wgpu=error,winit=error".into(),
                    level: bevy::log::Level::INFO,
                }),
            MaterialPlugin::<ShieldMaterial> {
                prepass_enabled: false,
                ..default()
            },
        ))
        .add_systems(Startup, setup)
        .add_systems(Update, (close_on_esc, make_visible, rotate))
        .run();
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ShieldMaterial>>,
) {
    commands.spawn((
        Camera3dBundle {
            camera: Camera {
                hdr: true,
                clear_color: ClearColorConfig::Custom(Color::BLACK),
                ..default()
            },
            exposure: Exposure::BLENDER,
            camera_3d: Camera3d::default(),
            tonemapping: Tonemapping::TonyMcMapface,
            transform: Transform::from_translation(Vec3::new(0., 0., 100.))
                .looking_at(Vec3::ZERO, Vec3::Y),
            ..default()
        },
        DepthPrepass,
        BloomSettings::default(),
    ));
    commands.spawn(DirectionalLightBundle {
        directional_light: DirectionalLight {
            illuminance: light_consts::lux::OVERCAST_DAY,
            shadows_enabled: false,
            ..default()
        },
        transform: Transform {
            translation: Vec3::new(4., 4., 10.),
            rotation: Quat::from_rotation_y(PI / 4.),
            ..default()
        },
        ..default()
    });

    let material = materials.add(ShieldMaterial {
        alpha_mode: AlphaMode::Add,
    });
    let num_ferris = 20;
    for (z, x) in (0..num_ferris).cartesian_product(0..num_ferris) {
        let transform = Transform::from_scale(Vec3::splat(4.0));
        commands.add(SpawnShieldedFerris {
            transform,
            shield: meshes.add(Sphere::new(2.0).mesh().ico(2).unwrap()),
            shield_material: material.clone(),
        });
    }
}

fn make_visible(mut window: Query<&mut Window>, frames: Res<FrameCount>) {
    if frames.0 == 3 {
        window.single_mut().visible = true;
    }
}

#[derive(Component)]
struct Object;

fn rotate(mut q: Query<&mut Transform, With<Object>>) {
    for mut t in q.iter_mut() {
        t.rotate(Quat::from_rotation_x(0.01));
    }
}

pub struct SpawnShieldedFerris {
    pub transform: Transform,
    pub shield: Handle<Mesh>,
    pub shield_material: Handle<ShieldMaterial>,
}

impl Command for SpawnShieldedFerris {
    fn apply(self, world: &mut World) {
        world
            .spawn(MaterialMeshBundle {
                mesh: self.shield,
                material: self.shield_material,
                transform: self.transform.clone(),
                visibility: Visibility::Visible,
                ..default()
            })
            .insert(NotShadowCaster)
            .insert(Object);
    }
}
