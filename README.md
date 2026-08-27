# Introduction
In this repo, I hope to attempt some Monte Carlo radiation dose simulation.
My goal is to have a system where I can define material geometry, beam profile, etc in files, and run a program that will run the Monte Carlo simulation and display in cross-sections the results.
For this project, I will be using the Odin programming language.
I chose this language because of its built-in support for graphics APIs and for its design, emphasising the performance and simplicity of C while having a nice standard library and syntax of modern languages.
This will be my first project using the language.

This project should not be used for any real scientific purposes.
As of writing, I have not really learned the radiation physics fundamentals needed for this, nor am I good at statistics, but I want to use this as an opportunity to improve in that regard.

# Progress
I currently handle the most basic case that I could think of.
I'm currently simulating what I believe to be a simple cone beam irradiating a solid block of water.
I am not yet using GPU for the simulation, but I am using CPU multithreading.
Currently, the only config that is read from a file is the mass attenuation coefficients that are read from exported XCOM data. The rest of the config is handled by the Odin code in `src/sim/setup.odin`.
For now, I am assuming a monoenergetic radiation beam and that the cone beam hits a flat surface of the geometry.
I also calculate dose by assuming a total dose since I lack real data and experience to use a beam profile.
The calculated dose is outputted to a `.raw` file, but I am still working on the display of cross sections.

# How to Run
