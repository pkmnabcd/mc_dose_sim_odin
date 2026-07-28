# Plan Purpose
In this file, I will outline my plan for the coordinate systems used in my program.
I want to get this written down so I don't get confused, and so I figure out the needed data and algorithms

# Coordinates Outline
## World Coordinates
The main set of coordinates will be the 'world coordinates', a term borrowed from computer graphics.
This will be the 3D coordinate system where all objects are placed.
The origin and basis vector directions are essentially arbitrary, and unit distance will be meters.

## Material Coordinates
The material will be represented by voxels.
For now, the unit distance between voxels will be 1mm.
The material's deposited energy will be tracked in a large 3D array with a coordinate system where the indexes of the arrays point to the centers of the voxels.
So, those coordinates map to physical coordinates such that the voxel indicated by `energy[2][30][20]` would represent a voxel whose center is at (2,30,20) in this coordinate system.

## Other Specific Systems
It may be helpful to keep track of certain objects in terms of their own coordinate system and then later transform back to world coordinates for application to the simulation.
For example, it may be easier to get a random sample from a rectangular cone beam field in a coordinate system where the center of the rectangle is at (0,0,0) and the rectangle is in the xy-plane.
From there, you can sample a coordinate and transform it to world coordinates for its actual placement.

# Changing Coordinate Systems
When changing coordinate systems, sometimes you can just do a translation, but if the coordinate systems don't have the same basis vectors, a more complicated conversion is needed.
In computer graphics, this often is done by a matrix multiplication.
I think for now, I will only support transformations that involve scaling, translation, and rotation about an axis.
This means that each coordinate transformation should involve two coordinate systems that share at least one of xy, yz, xz plane after a translation.

Say that we're going from material coordinates to world coordinates.
I think that I'll try to keep the basis vectors the same except different scaling.
Say that the material unit length is $a$ times world unit length.
This implies that for a coordinate in material coordinates $P$, the associated coordinate in world coordinates $P'$ is the following.
Note that we use the 4-coordinate version of $P$ to simplify translation.
$$
P'=
\begin{bmatrix}
a & 0 & 0 & 0 \\\
0 & a & 0 & 0 \\\
0 & 0 & a & 0 \\\
0 & 0 & 0 & 1 \\\
\end{bmatrix}
P
$$

If the transformation also requires a translation and rotation, then we get the following transformation.
$$
P'=
\begin{bmatrix}
1 & 0 & 0 & b_x \\\
0 & 1 & 0 & b_y \\\
0 & 0 & 1 & b_z \\\
0 & 0 & 0 & 1 \\\
\end{bmatrix}
R
\begin{bmatrix}
a & 0 & 0 & 0 \\\
0 & a & 0 & 0 \\\
0 & 0 & a & 0 \\\
0 & 0 & 0 & 1 \\\
\end{bmatrix}
P
$$
where $b_q$ indicates a translation in each direction and $R$ is the matrix of rotation (there are different ones for rotation about each axis).

If I were to transform a coordinate the other way, I would just need to compute the inverse matrix $(M)^{-1}$, and that matrix would be used to go back.
$$P=(M)^{-1}P$$

# Finding the Closest Coordinate
During the simulation, I will be tracking the angle of photons and how far they go until the next interaction.
This implies that I will have to place the next interaction at a voxel, which has discrete points, unlike the continuous world coordinates.
So, I will have to find a way to decide which voxel to put whatever energy into.
