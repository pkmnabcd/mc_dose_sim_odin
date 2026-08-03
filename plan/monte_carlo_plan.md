# Plan Purpose
In this file, I will outline my plan for the Monte Carlo radiation simulation.
I will learn about and figure out the algorithms involved, and I will outline how I will implement the algorithms using the GPU.

# Outline
## Init
There is an inital state where we have our grid of material and locations and directions of photons entering (from the beam parameters).
This is the starting point for the simulation.
For now, I assume that the material is homogeneous.
From parameters, I will determine the volume of the voxels and the mass for dose calculations.

## General Process
For particles traveling through a medium, there exist attenuation coefficients that are the probability of interaction per unit particle path length.
Mu is actually the sum of the various attenuation coefficients of the phenomena you're including in your simulation.
For example, I intend to include the photoelectric effect, Compton scattering, and pair production for photon-matter interactions, so mu = mu_photo + mu_compton + mu_pair.

The distance a photon/particle goes without an interaction I found to be x = -ln(rand_num) / mu where rand_num is between 0.0 and 1.0.
At the distance determined, the interaction is determined using the relative probabilites.
For example:
Generate a second random number and do the following.
* Photoelectric effect if 0 <= rand_num < mu_photo / mu
* Comtpon if mu_photo / mu <= rand_num < (mu_photo + mu_compton) / mu
* Pair production if (mu_photo + mu_compton) / mu <= rand_num <= 1
From there, more random numbers may be needed (like determining what angle things are for Compton scattering)

There will be a primary particle and secondary particle queue.
The incoming beam's particles are in the primary queue.
Since I'm planning to try to use GPU, I will simulate one photon N times before putting it in the secondary particle queue.
Once the interaction is determined, the resulting particle(s) are put into the queue.
Once the photons/particles have gone below some energy threshold, they will be determined to have deposited all their energy into their current voxel.

## Interaction Handling
For my first draft, I will simplify the simulation (and the physics) by assigning all the energy from charged particles generated from photon-matter interactions to the voxel where the interaction occurs.
I feel justified in this because it seems like this largely how openMC handles it.
See its discussion on [heating and energy deposition](https://docs.openmc.org/en/stable/methods/energy_deposition.html).
I'm not certain if this is what I should do, but when there is an electron dislodged from an atom, I will assume that both the binding energy and the electron kinetic energy go into dose.

I'll now outline how I'll handle the various interactions.

### Photoelectric Effect
If the photoelectric effect occurs, all the photon's energy is put into the voxel.

### Compton Scattering
Here, the incident photon is deflected, so some of its energy will be put into an electron (dose), while the rest stays with the deflected photon.
TODO: figure out the order and algorithm to decide the energy lost from photon and the angle it goes.
With k = incident photon energy / electron rest mass energy and k' = leaving photon energy / electron rest mass energy, we know that k' = k / (1+k(1-mu)), with mu = cos(deflection angle).
First, `mu` will be determined by using the same method as `openMC`, using Kahn's rejection method for k < 3 and Koblinger's method for k >= 3.
Note: `alpha` in the `openMC` code refers to `k`.

Once `mu` is found, k' is found using the above formula.
Normally, I would then consider the form factor, but I will be neglecting that for now.
With this, the energy put into an electron will be added to the dose for the voxel.
The remaining photon's new angle is computed.
This can be done in a manner similar to `openMC` (see notes).

The application of the angles to change the direction vector is done according to the section below.

#### Kahn's Rejection Method
See the below paper and the source code for openMC: `klein_nishina` in `photon.cpp` for how this can be done.

#### Koblinger's Direct Method
See the below paper and the source code for openMC: `klein_nishina` in `photon.cpp` for how this can be done.

#### Applying the Angle to Photon Direction
Once we have the deflection angle $\theta$ and have randomly sampled the azimuthal angle $\phi$, the direction of the photon is changed by assuming that the initial photon direction is the polar angle and use spherical-to-cartesian coordinates to put the new vector in that coordinate system.
Then, we can use the photon direction in world coords as a basis and come up with two more basis vectors to create an orhtogonal basis.
With this, we can do a change of basis by putting those three basis vectors in a matrix as column vectors and multiply it by the new local coords vector to get the new direction in world coordinates.

Define $v_\text{local}$ as the deflected direction in the local coordinate system (where the incident direction is in the polar $\hat{z}$ direction). Then,

$$v_\text{local}=
\begin{bmatrix}
\sin(\theta)\cos(\phi)\\\
\sin(\theta)\sin(\phi)\\\
\cos(\theta)\\\
\end{bmatrix}
$$

Say that in world coordinates, we have the incident direction $v_1$ and two other vectors $v_2$ and $v_3$ that form an orthonormal basis, and that they are described in world coordinates.
These form the following matrix $M$ that can retrieve the world coordinates of the new direction by the following (change of basis).

$$v_\text{world}=Mv_\text{local}$$

where

$$M=
\begin{bmatrix}
v_1 & v_2 & v_3 \\\
\end{bmatrix}
$$

The basis vectors are used as column vectors.

### Pair Production
For now, pair production will be treated like the photoelectric effect since I'm simplifying the charged particle model.

# Notes
* Great resource is the documentation for [openMC](https://docs.openmc.org/en/stable/methods/index.html).
    * It seems like they mostly put the energy in charged particles in the voxel they're created, so that can be a good shortcut for the start. See section [11. Heating and Energy Deposition](https://docs.openmc.org/en/stable/methods/energy_deposition.html).
* See [this paper](https://aapm.onlinelibrary.wiley.com/doi/10.1002/mp.17899) for details on how to optimize MC simulation for GPU.
    * They separate GPU cores into photon and electron cores, and they simulate each particle a certain number of times before putting them in the queue.
* Paper illustrating how Koblinger's direct method can be implemented. [Here](https://www.sciencedirect.com/science/article/pii/S1877705811054865).
* Paper illustrating how Khan's rejection method can be implemented. [Here](https://www.sciencedirect.com/science/article/pii/S1877705811021552).
* Most important code for openMC [here](https://github.com/openmc-dev/openmc/blob/db673b9acb400d15be3df98ea0492486ff820866/src/photon.cpp).
* See `rotate_angle` function for how to rotate the vector for compton scattering [here](https://github.com/openmc-dev/openmc/blob/ed5b7a2990199a89489041c9824bf6e7e6055217/src/math_functions.cpp#L772). Recall that `mu = cos(theta)`.
* See this description for rotating a particle's coordinates for when compton scattering [here](https://docs.openmc.org/en/stable/methods/neutron_physics.html#transforming-a-particle-s-coordinates)
