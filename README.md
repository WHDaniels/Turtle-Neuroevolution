# Turtle-Neuroevolution
#### Investigating simple adaptive agent cognition through neuro-evolution and competitive environments.
A semester-long project under the guidance of Dr. Uri Wilensky at [Northwestern's Center for Connected Learning and Computer-Based Modeling (CCL)](http://ccl.northwestern.edu/) through his Designing and Constructing Models with Multi-Agent Languages course.

### Summary
A NetLogo agent-based model of competitive neuroevolution. "Turtle" agents compete for food so they can reproduce, and their offspring have a change to mutate their neural network brains randomly. Turtle brains are one of 4 neural networks types, which can be chosen before starting the simulation.

### Running
Install the newest versions of PyTorch and NumPy into a local virutal Python environment. The given 'network.py' file is the basis for each agents brain, and containts the necessary mutation and action functions. Place this file into your created 'venv' (virtual enviroment) folder. [This line](TurtleEvoSim.nlogo#L15) should point to the Python path in the virutal environment.
