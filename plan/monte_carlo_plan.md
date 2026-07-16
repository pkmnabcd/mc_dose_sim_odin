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
For electron-material interactions, I will include inelastic collisions with atomic electrons and inelastic collisions with the nucleus.

The distance a photon/particle goes without an interaction I found to be x = -ln(rand_num) / mu where rand_num is between 0.0 and 1.0.
At the distance determined, the interaction is determined using the relative probabilites.
For example:
Generate a second random number and do the following.
* Photoelectric effect if 0 <= rand_num < mu_photo / mu
* Comtpon if mu_photo / mu <= rand_num < (mu_photo + mu_compton) / mu
* Pair production if (mu_photo + mu_compton) / mu <= rand_num <= 1
From there, more random numbers may be needed (like determining what angle things are for Compton scattering)

Once the interaction is determined, the resulting particle(s) are put into the queue.
Once the photons/particles have gone below some energy threshold, they will be determined to have deposited all their energy into their current voxel.

## Dose Deposition
Dose is deposited in many, but not all interactions.

# Notes
* Great resource is the documentation for [openMC](https://docs.openmc.org/en/stable/methods/index.html).
    * It seems like they mostly put the energy in charged particles in the voxel they're created, so that can be a good shortcut for the start. See section [11. Heating and Energy Deposition](https://docs.openmc.org/en/stable/methods/energy_deposition.html).
