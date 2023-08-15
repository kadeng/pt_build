
# Enabling Pytorch Mixed-Mode Debugging

### Why mixed mode debugging?

As a developer in the process of onboarding into the [Pytorch](https://github.com/pytorch/pytorch) codebase, I had a few occasions
when it became very hard to trace through the execution flow. Pytorch is a codebase where call stacks can effectively span 3 languages,
most notably Python, C/C++ and Nvidia's CUDA C++. Each of these requires more or less a different debugger to step through. 

If we would have a python debug build, we could use [Python's GDB extension](https://devguide.python.org/development-tools/gdb/index.html) to step through
both native- and python code. Even more than that, we could even use [cuda-gdb](https://docs.nvidia.com/cuda/cuda-gdb/index.html) with said extension

Sadly, when we follow the [Pytorch build from source instructions](https://github.com/pytorch/pytorch#from-source), **we don't have a python debug build**
because it completely relies on an Anaconda/Miniconda provided Python executable. 

To my personal knowledge, it is therefore not trivial to obtain a debug build of Pytorch with CUDA support, running in a debug build of python. The scripts
in this folder aim to change that.

### A debug build environment for Pytorch 

This repository is a prototype of a reproducible build environment for Pytorch based on an [Apptainer](https://apptainer.org/) (formerly known as Singularity)
image definition.

The contained apptainer image can be built and consecutively run without any root / sudo privileges, and possibly even completely isolated from network and filesystem,
on Linux hosts with or without CUDA-capable GPUs. The container image contains

 * **All libraries required to arrive at a debug build of Pytorch 2** ( tested with a recent checkout of the **main** branch of pytorch as of 2023-08-15 ) 
 * This includes the **CUDA Toolkit** and **Intel MKL** as well as **AMS's ROCm Framewrork** ( even if it's not used atm)
 * A **debug build of python 3.11.3**, including the **python-gdb.py** script which extends gdb with mixed-mode debugging capabilities.
 * A non-debug build of **python 3.9** - which is required by cuda-gdb to run the **python-gdb.py** script ( python>3.9 is not supported by cuda-gdb )
 * An **environment-script** to set up all neccessary environment variables to easily arrive at a mixed-mode debug build of Pytorch.

In addition, this document contains all neccessary instructions to build and debug Pytorch in mixed mode.

### Getting Started

#### Build the image

 * Start by installing  [Apptainer](https://apptainer.org/) on the Host system. Usually via the Linux package manager of your choice, for example via "sudo dnf install apptainer".
 * Check out this repository or otherwise transfer it's contents to the host system. 
 * Change to the directory of this repo.

Now create your apptainer image ( called pytorch_builder.sif" ) via the following command:

```bash
singularity build pytorch_builder.sif pytorch_build_archlinux.apptainer.def
```

This will take a pretty long time to build (one to several hours) and creates an image file (pytorch_builder.sif) of approximately 18 GB of size, so
make sure you have enough disk space. In contrast to previous versions of Singularity / Apptainer, all this can be done
in a completely unprivileged manner. 

Note: Apptainer images do not have to be built and used on the same host, so if your final GPU host is behind a firewall
or such, you can also build the image elsewhere and transfer the .sif file afterwards. 

You should also create an **overlay** directory next to the image, this overlay can be used to persist changes
you make to the filesystem, without overwriting the (compressed) image file:

```
mkdir pytorch_builder_fs_overlay
```

####  Build pytorch

Once you have built the image, you can enter it and build pytorch. Assuming you have checked out pytorch already
to **~/github/pytorch/pytorch** within your user's home directory, the following should do it:

```bash
apptainer run --overlay pytorch_builder_fs_overlay pytorch_builder.sif bash
```

 **Note**: While it is possible to completely isolate the code within the container such that it cannot access the host
  system, by using the "--containall --net --network none" arguments to apptainer, this tutorial would be unneccessarily
  complex if we did that in the given examples.  


Within the container, make sure the **neccessary environment variables** are set:


```bash
source /usr/local/bin/pytorch_build_env.sh
```

If you want to change any of the environment variables mentioned in pytorch's setup.py, now would be the time. 
The build process is tested with the ones from said script, though.

**Now change to the pytorch source directory**

```bash
cd ~/github/pytorch/pytorch
```

and create a **Python virtual environment** first and enter it

```bash
python -m venv .venv
source .venv/bin/activate
```

Next, **install the required python packages**

```bash
pip install -r requirements.txt
pip install -r requirements-flake8.txt
pip install pytest expecttest
```

Now, if neccessary, **clean** the previous build files:

```bash
rm -rf build
python setup.py clean
```

Now you are ready to **start the build**:

```
python setup.py develop
```

if all goes well, you should now have a virtualenv ( don't forget to activate it again when reentering) that uses a debug build of python
and has a debug build of a recent pytorch with CUDA enabled.

## Mixed Mode debugging using gdb

**Note:** These instructions also work with **cuda-gdb** found in /opt/cuda/bin/cuda-gdb

Mixed-mode debugging is now rather straightforward. Let's say you want to debug
a unittest that you would normally execute like this:

```bash
python -m pytest test/inductor/test_fused_attention.py -k _9
```

In order to do that, first you might want to reenter the image and the virtualenv:

```bash
apptainer run --overlay pytorch_builder_fs_overlay pytorch_builder.sif bash
cd ~/github/pytorch/pytorch
source .venv/bin/activate
```

Now, **launch gdb with python extension** like this:

```bash
gdb -x /usr/bin/python-gdb.py python
```

You're entering the normal gdb interactive shell. If you want to have a nicer view of the source, try this:

```
gdb -x /usr/bin/python-gdb.py --tui python
```

You can now set breakpoints as usual in gdb in native code. As to python breakpoints, we will come to that.

Now run your python command as you normally would:

```
run -m pytest test/inductor/test_fused_attention.py -k _9
```

When you break into the debugger now, you have special python commands
like **py-bt** (python-backtrace), **py-p** (python-print), **py-up** and **py-down**
as well as **py-list**. All that is [well explained here](https://devguide.python.org/development-tools/gdb/index.html)

If you want to break into gdb from python code, I recommend sending the SIGTRAP signal to your own process, which will break into the debugger:

```
import os
import signal

os.kill(os.getpid(), signal.SIGTRAP)
```

### Nicer GDB User Interface

gdb doesn't have a nice user interface, sadly. While running in an isolated container, it might prove hard to use any form of remote-debugging that does not use
a console.

Therefore I recommend launching gdb with the "--tui" option, or using something like vim's **'cpiger/NeoDebug'** plugin, which even works with cuda-gdb. 
