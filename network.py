import torch
import random
import torch.nn as nn
import numpy as np
import time
import itertools

np.warnings.filterwarnings('ignore', category=np.VisibleDeprecationWarning)

class SingleLayer(nn.Module):
    def __init__(self, num_inputs=3, num_outputs=3):
        super(SingleLayer, self).__init__()

        # Inputs are an array of perceptions
        self.num_inputs = num_inputs
        self.num_outputs = num_outputs

        # Layer takes num_inputs inputs, gives num_outputs outputs
        self.input = nn.Linear(num_inputs, num_outputs, bias=False)
        self.input.weight = nn.init.normal_(self.input.weight, mean=0, std=2.5)
        self.softmax = nn.Softmax(dim=0)

    def forward(self, x):
        return self.softmax(self.input(x))


class MultiLayer(nn.Module):
    def __init__(self, num_inputs=3, num_hidden=3, num_outputs=3):
        super(MultiLayer, self).__init__()

        # Inputs are an array of perceptions
        self.num_inputs = num_inputs
        self.num_outputs = num_outputs

        # Layer takes num_inputs inputs, gives num_hidden outputs
        self.input = nn.Linear(num_inputs, num_hidden, bias=False)
        self.input.weight = nn.init.normal_(self.input.weight, mean=0, std=2.5)

        # Layer takes num_hidden inputs, gives num_outputs outputs
        self.hidden = nn.Linear(num_hidden, num_outputs, bias=False)
        self.hidden.weight = nn.init.normal_(self.hidden.weight, mean=0, std=2.5)

        self.act = nn.Tanh()
        self.softmax = nn.Softmax(dim=0)

    def forward(self, x):
        return self.softmax(self.hidden(self.act(self.input(x))))


def mutate(net, mutation_rate=0.1, multi_layer=False):
    """
    Alters one of the weights of the agent net.
    :param net: The agent's neural network instance.
    :param mutation_rate: Chance for each individual weight to change.
    :return: The altered network.
    """
    with torch.no_grad():
        mutated = False

        if not multi_layer:
            numpy_weights = [net.input.weight.numpy()]
        else:
            numpy_weights = [net.input.weight.numpy(), net.hidden.weight.numpy()]

        # Change weights randomly based on the mutation_rate
        for i, layers in enumerate(numpy_weights):
            for j, layer in enumerate(layers):
                for k, weight in enumerate(layer):
                    if random.random() < mutation_rate:
                        mutated = True
                        numpy_weights[i][j][k] += random.normalvariate(0, random.random() * 5)

        net.input.weight = nn.Parameter(torch.Tensor(numpy_weights[0]))
        if multi_layer:
            net.hidden.weight = nn.Parameter(torch.Tensor(numpy_weights[1]))

    return net, mutated


def get_action(net, inputs):
    """
    Gets the next action of the agent.
    """

    with torch.no_grad():
        input_tensor = torch.Tensor(inputs)
        result = net(input_tensor).numpy()

    return result


if __name__ == '__main__':
    # net = MultiLayer()
    # print([p for p in net.parameters()])
    pass
