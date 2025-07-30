# CityCrafter 3D    <img width="50" height="50" alt="image" src="https://github.com/user-attachments/assets/2002892d-fca9-46d3-aef8-d6dde141913c" />

City Generation tool for Godot 4.4

## Description
This is a city generator that builds cities using a slot-based grid system. Each block can be different sizes (1x1, 2x1, 2x2), and blocks are assigned district types (residential, commercial, industrial) using noise or random placement.
* Buildings are placed based on the district and density settings, and can be reused by saving the CityConfiguration resource.
* Visuals and materials are pulled from your assigned assets in the configuration.
* Support for further subdivision and smaller subroads in residential zones.
* All generated components are standalone nodes within the world, allowing for post-generation adjustments.

## What this tool is:
* A fast way to generate blocky, retro-style city layouts.
* A good starting point for developers that don't have the time or skill to manually place hundreds or thousands of buildings.

## What this tool is NOT:
* This does not do all the work for you - You will most likely need to do manual cleanup, move buildings on occasion, etc. especially if you're using unique tscn files. This tool is designed to give you a strong framework, but procedural generation cannot replace true artistic creativity.
* This doesn't optimize scenes for you - There's some material and mesh sharing with the roads/intersections, but if your building tscn files don't follow best practices, CityCrafter won't fix your mistakes. See the tips section for help in that regard.

## Installation
It is recommended to download this plugin from the Asset Store, but if you download it from this repository or another page, simply copy the citycrafter folder into the res://addons/ folder in your file system. Make sure to enable the plugin in your project settings and restart the project to clean up any errors. 

## Using the tool
> #### I highly recommend starting with the example_scene to see how everything works
To begin, add a CityCrafter node to your scene. You will then need to go into the inspector at the top and create a new CityConfiguration. Buildings will generate in their respective districts if they are placed in that district's array.  
  
## Configuration Overview
All generation settings are managed through the `CityConfiguration` resource.
| Section                 | Property                     | Description                                      |
|------------------------|------------------------------|--------------------------------------------------|
| **Building Collections** | `residential_buildings`      | Array of residential building scenes             |
|                        | `commercial_buildings`       | Array of commercial building scenes              |
|                        | `industrial_buildings`       | Array of industrial building scenes              |
| **Materials**          | `road_material`              | Material used for primary road segments          |
|                        | `intersection_material`      | Material used for intersections                  |
|                        | `subdivision_road_material`  | Material used for subdivision roads              |
|                        | `ground_material`            | Default ground material                          |
|                        | `residential_ground_material`| Override ground for residential blocks           |
|                        | `commercial_ground_material` | Override ground for commercial blocks            |
|                        | `industrial_ground_material` | Override ground for industrial blocks            |
| **City Layout Settings** | `grid_width`                | Number of blocks horizontally                    |
|                        | `grid_height`                | Number of blocks vertically                      |
|                        | `block_size`                 | Size of a standard block in world units          |
|                        | `street_width`               | Gap between blocks (road width)                  |
|                        | `empty_block_chance`         | Chance a block is skipped entirely               |
| **Multi-Size Blocks** | `enable_multi_size_blocks`   | Enables 2x2, 2x1, 1x2 block types                |
|                        | `large_block_chance`         | Chance of spawning a 2x2 block                   |
|                        | `wide_block_chance`          | Chance of spawning a 2x1 block                   |
|                        | `tall_block_chance`          | Chance of spawning a 1x2 block                   |
| **City Shape Variations** | `enable_edge_variations`  | Enables edge distortion for outermost blocks     |
|                        | `edge_variation_chance`      | Chance of variation per edge block               |
|                        | `max_edge_variation`         | Maximum units of offset at edges                 |
|                        | `enable_random_extensions`   | Adds random branches outside the grid            |
|                        | `random_extensions_count`    | Max number of branches to try                    |
|                        | `extension_spawn_chance`     | Chance of each branch spawning                   |
| **District Settings** | `district_mode`              | Enum: noise-based, zoned, or random              |
|                        | `residential_ratio`          | Ratio of city blocks for residential             |
|                        | `commercial_ratio`           | Ratio of city blocks for commercial              |
|                        | `industrial_ratio`           | Ratio of city blocks for industrial              |
|                        | `noise_scale`                | Controls how zoomed in the noise pattern is      |
| **Residential Density** | `enable_residential_subdivisions` | Enables subdivision inside blocks         |
|                        | `subdivision_mode`           | Enum: fixed or random layout                     |
|                        | `subdivision_layout`         | Enum: 2x2, 2x3, or 3x3 layout                    |
|                        | `subdivision_street_width`   | Width of internal subdivision roads              |
|                        | `residential_buildings_min`  | Min number of residential buildings per block    |
|                        | `residential_buildings_max`  | Max number of residential buildings per block    |
|                        | `residential_spacing`        | Minimum spacing between residential buildings    |
|                        | `residential_border_margin`  | Margin around residential blocks                 |
| **Commercial Density** | `commercial_buildings_min`   | Minimum buildings per commercial block           |
|                        | `commercial_buildings_max`   | Maximum buildings per commercial block           |
|                        | `commercial_spacing`         | Spacing between commercial buildings             |
|                        | `commercial_border_margin`   | Margin around commercial block edges             |
| **Industrial Density** | `industrial_buildings_min`   | Minimum buildings per industrial block           |
|                        | `industrial_buildings_max`   | Maximum buildings per industrial block           |
|                        | `industrial_spacing`         | Spacing between industrial buildings             |
|                        | `industrial_border_margin`   | Margin around industrial block edges             |
| **Building Variations** | `rotation_mode`             | Enum: Free, 90 Degrees, or No Rotation           |
|                        | `scale_variation`            | Randomized scale offset (-1.0 to 1.0)            |
| **Ground and Roads**   | `generate_roads`             | Enables road mesh generation                     |
|                        | `generate_intersections`     | Enables intersection mesh generation             |
|                        | `intersection_height_offset` | Z-offset for intersections                       |
|                        | `generate_subdivision_roads` | Enables roads inside subdivisions                |
|                        | `generate_ground`            | Enables flat ground generation                   |
|                        | `ground_height_offset`       | Z-offset for ground mesh                         |

## Performance Tips
### Scene Optimization
* Use shared resources! A building should reuse materials and meshes as much as possible
* Only use collision if you have to, and pay attention to layers! Having all these buildings on every layer will destroy performance. And if possible, avoid using the "create collision shape" option in the editor for your meshes. Just create a simple shape.
* Since the placed buildings aren't any different than a standard scene, it is possible to bake occlusion.
### Tool Use
* Once you click the generate city button, it's going to keep going until it's done, so be prepared to be patient.
* Keep the grid height and witdh reasonable when starting out (default values) and confirm your computer can handle the processing before you get really big.
* Adding different-sized blocks and/or subdivisions will increase generation time
* Make sure to save your ground and road materials as explicit resources to save some memory.

## Credits for example_scene:
### Kenny City Kit: Commercial
https://kenney.nl/assets/city-kit-commercial (CC0)
### Kenny City Kit: Industrial
https://kenney.nl/assets/city-kit-industrial (CC0)
### Kenny City Kit: Suburban
https://kenney.nl/assets/city-kit-suburban (CC0)

## Contributing
I'm happy to work with others on this. If you have suggestions or want to improve the code, please reach out to me on my ![Itch.io Page](https://immaculate-lift-studio.itch.io/) or submit an issue/pull request on this repository. If you like what I'm doing and want to support me, please [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/C0C8YOTVD)

## License
MIT. I hope this helps somebody in their Godot journey!
