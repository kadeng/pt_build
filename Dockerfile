# This is ==archlinux:latest at the time of writing of this Dockerfile
FROM archlinux:base-20230723.0.166908 as baseimg

RUN pacman -Syu --noconfirm
RUN pacman -S --noconfirm base-devel git python asp wget
RUN pacman -S --noconfirm google-glog gflags opencv openmp nccl pybind11 python-yaml
RUN pacman -S --noconfirm libuv python-numpy python-sympy python-future
RUN pacman -S --noconfirm protobuf ffmpeg4.4
RUN pacman -S --noconfirm qt6-base intel-oneapi-mkl
RUN pacman -S --noconfirm python-typing_extensions numactl python-setuptools python-yaml python-numpy cmake
RUN pacman -S --noconfirm ninja doxygen
RUN pacman -S --noconfirm shaderc
RUN pacman -S --noconfirm cuda
RUN pacman -S --noconfirm cudnn
RUN pacman -S --noconfirm rocm-hip-sdk roctracer
RUN pacman -S --noconfirm miopen
RUN pacman -S --noconfirm vulkan-headers
RUN mkdir -p build/python-pytorch && cd build && asp checkout python-pytorch
COPY pytorch_setup /usr/local/bin/pytorch_setup
RUN chmod +x /usr/local/bin/pytorch_setup
RUN pacman -S --noconfirm ccache

#FROM baseimg as bpk
#ARG PYTORCH_GIT_REV=main
#ARG PYTORCH_PKG_VER=2.1.devel
#RUN pacman -S --noconfirm vim strace gdb valgrind
# Update PKGBUILD to check out the git revision we want
#RUN cd build/python-pytorch/trunk && sed -i "s/^pkgver=.*/pkgver=${PYTORCH_PKG_VER}/" PKGBUILD
#RUN cd build/python-pytorch/trunk && sed -i "s/^_pkgver=.*/_pkgver=${PYTORCH_GIT_REV}/" PKGBUILD
#RUN cd build/python-pytorch/trunk && sed -i "s/pytorch.git\#tag=v\$_pkgver/pytorch.git\#tag=\\\$_pkgver/" PKGBUILD
# This patch is broken in more recent versions of pytorch. Emptying the patch is the safest way to disable it.
#RUN touch build/python-pytorch/trunk/use-system-libuv.patch && mv build/python-pytorch/trunk/use-system-libuv.patch build/python-pytorch/trunk/use-system-libuv.patch.bak && touch build/python-pytorch/trunk/use-system-libuv.patch
# Make the image a bit more compact
#RUN rm /var/cache/pacman/pkg/*
#RUN useradd -m builder
#RUN chown -R builder build
# This step already does prepare(), which applies patches and checks out submodules recusively
#RUN cd build/python-pytorch/trunk && su builder -c "makepkg --noconfirm --nobuild --nocheck --skipchecksums"
# Shis step actually builds, while holding the version (e.g. no new git pulls )
#RUN cd build/python-pytorch/trunk && su builder -c "makepkg --noconfirm --noprepare --holdver --nocheck"


