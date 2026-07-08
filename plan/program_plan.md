# Program
This program should read structs that have information about the beam, material, etc.
It should then run the simulation using those parameters.
Once it is finished, the array with the finished model is sliced, and those slices are fed to the GPU to be presented.

# Main Packages
The following is the current plan for the layout of the packages.
* **Parse Package:** Read beam and material parameters
    * This will be largely skipped while figuring out the rest of the system.
    * *Input:* File locations and files.
    * *Output:* Strucs with the relevant beam and material data
        * This will include the shape of the material and beam, the energy and directions of the beam, and the relevant physical coefficients relevant to the simulation.
* **Simulation Package:** Run the simulation.
    * This is the most important part, and should be focused on first.
    * *Input:* The structs that detail the initial parameters of the simulation. Also options for the simulation.
    * *Output:* The results of the sim: the deposited dose put in the material. So, it should be 3D array with the dose as the main value. I think I'll write the data to a file.
* **View Package:** Present the simulation.
    * *Input:* The simulation result file location and visualization config/settings.
    * *Output:* The graphical output: cross sections of the model.
