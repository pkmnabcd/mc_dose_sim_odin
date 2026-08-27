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
This program is written in the Odin programming language, so you will need the odin compiler.
I have been using `odin version dev-2026-06-nightly:7ab61e4`.
Odin isn't completely stable yet, so it's possible that a significantly older or newer version wouldn't work.

Once you have the compiler, simply run `odin build src/sim` in the project root directory.
This will compile the program.
To run the simulation, run `./sim`.
Note that this (in the default state) will create a 4 GB file called `dose.raw` in that directory with the output of the simulation.

This requires that you have XCOM data covering 1 keV photon energy up to your initial photon energy saved at `data/water_xcom.txt`.
This XCOM data should include all possible columns from the dataset (useless ones are filtered out by the program), and they should look like the following.
```
1.000E-03 1.372E+00 1.319E-02 4.076E+03 0.000E+00 0.000E+00 4.077E+03 4.076E+03
1.500E-03 1.269E+00 2.673E-02 1.374E+03 0.000E+00 0.000E+00 1.376E+03 1.374E+03
2.000E-03 1.150E+00 4.184E-02 6.162E+02 0.000E+00 0.000E+00 6.173E+02 6.162E+02
3.000E-03 9.087E-01 7.075E-02 1.919E+02 0.000E+00 0.000E+00 1.928E+02 1.919E+02
...
```
So there should be no comments or headers.

You can adjust certain parameters by modifying the `src/sim/setup.odin` file and recompiling.
