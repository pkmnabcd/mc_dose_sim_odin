# Plan Purpose
In this file, I will outline my plan for setting up the simulation.
There will be a config file with settings and locations of data.

# Needed Data
The following data files are needed.
## In Config File
* The mass density of the material you're using
* The number of beam particles to simulate
* 

## Separate Files
* The XCOM dataset with the Mass Cross sections
* In the future, geometry can be specified
* In the future, the radiation beam can be specified

# Setup Process
This version of the setup will be used for the time being while I set up the whole system.

## Material
For now, I'll just fill a cube grid of uniform material.
The simulation is mostly built for water, but you can put in whatever material you want by changing the density and cross sections.
Make sure the cube has and odd number of rows/cols/etc so it has an easily defined center.

## Radiation Beam
The radiation beam will for now just be a cone beam at uniform energy.
I'll define a certain source distance relative to the center of the cube and aim the beam towards that center.
With that a source position can be defined.
We'll say that the surface is flat, and that the distribution of photons across it is even.
Say the field surface is a rectangle with length L and width W.
We can uniformly sample a coordinate across the field (say the center of field is (0,0) ) with x in (-L/2 , L/2) and y in (-W/2 , W/2).
Must make sure that each coordinate corresponds with a voxel position.
Call this coordinate P_target(x,y,z).
The photon direction will be D(x,y,z) = (P_target - P_source) / (|| P_target - P_source ||).

An amount of desired energy output E_des will be defined.
Since we're doing uniform photon energy, the total simulated energy E_sim is photon energy * photon count N.
Once the simulation is done, multiply the energy at each voxel by E_des / E_sim.
