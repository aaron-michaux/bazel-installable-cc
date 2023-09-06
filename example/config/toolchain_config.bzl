"""
Contains TWO parameters: URLs and MANIFEST
"""

# The list of URLs to attempt to download toolchains from
URLS = [
    "http://localhost/downloads/toolchains",
    # TODO, add github URL here
]

# (sha256 archive) pairs, specifying available toolchains, # lines ignored
# The "--" values in filename are necessary for parsing parts
#     <compiler>--<cpu>--<vendor>--<os>
MANIFEST = """
# Oracle Linux 8.8
721fbf86e9ab2e9b181cb32224d9e5e7e286c4452eadee5fc3e8f37af433bf79  gcc-9.5.0--x86_64--ol-8.8--linux.tar.xz
4078ed184cfb57dab01e70c4019491500a1ac38029ebb081a8f45c2af14f917d  gcc-10.5.0--x86_64--ol-8.8--linux.tar.xz
282000f5fd77f99f5c9cab822a12ef7676bce8166a50b78e62bb7b68f5ee7205  gcc-11.4.0--x86_64--ol-8.8--linux.tar.xz
43d5e5934572a95b437d17739a371769a9ca495d76af897d96fbeefbf4bd1132  gcc-12.3.0--x86_64--ol-8.8--linux.tar.xz
56c33f654398aaee3f78f0db598a6d254a23df482cd929e755bafdcd3fccccd8  gcc-13.2.0--x86_64--ol-8.8--linux.tar.xz
ccab22a5b9baea5ad5d222eacaded9bd43e9939322c4a033b1ed8293372bf173  llvm-12.0.1--x86_64--ol-8.8--linux.tar.xz
066c815cd4604b4f7c310da152931be1ec9523c70fbf0d7c0a3cfa257d41420a  llvm-13.0.1--x86_64--ol-8.8--linux.tar.xz
be20eda6fa42ed76970965ff4f6386126121a347cc7de7af4e5094f9fb428501  llvm-14.0.6--x86_64--ol-8.8--linux.tar.xz
5a50f3b0606e697515e5058656f57b3a8832da0bedd04f3dc4ca4c34bc26a4d6  llvm-15.0.7--x86_64--ol-8.8--linux.tar.xz
389ffaf3e2538670373e9e975e0cdf23284a43b3914c44f060f9229c68c452d7  llvm-16.0.6--x86_64--ol-8.8--linux.tar.xz

# Debian 10 Bullseye
c91730c311fa2b3044c474622ebf76ffb5fcbecf07aa82af25e60bc1d88fa468  gcc-9.5.0--x86_64--debian-bullseye--linux.tar.xz
fc4576571e3e8a81e03b40debe6e06f45cd028903f89520908d5ac34767c1535  gcc-10.5.0--x86_64--debian-bullseye--linux.tar.xz
775f9de7b4340c194b9cc24738939ed87c759c49425b122cbe53087ccaef57d8  gcc-11.4.0--x86_64--debian-bullseye--linux.tar.xz
484b3a36a9387a00c5c91eecba3165c0134224e2fd748f5f089e89d0e6d0a02c  gcc-12.3.0--x86_64--debian-bullseye--linux.tar.xz
8ea2b82c9700ce36f1455c39a87238ed63b5b334c7a487f7c6c59addf5a2512e  gcc-13.2.0--x86_64--debian-bullseye--linux.tar.xz
8dd5533b1230f1cecedbc0e264d2267bf344e09bb4e00f36a1f8ee98c56ba923  llvm-12.0.1--x86_64--debian-bullseye--linux.tar.xz
75081244f9431db3a792b85f9742072c9d1002cc6b4717d8c7727c7060f1a536  llvm-13.0.1--x86_64--debian-bullseye--linux.tar.xz
ebff6a1dcaae9d6789130e3f138eb7a58758e300b211cb4944aa72da7a934fd8  llvm-14.0.6--x86_64--debian-bullseye--linux.tar.xz
b2fa79a62bd76a93ece28c095aaa1b91038014b19be1278d56951752b190ba53  llvm-15.0.7--x86_64--debian-bullseye--linux.tar.xz
8ca768df8f8f865f0099d343a305285ff8b70dced5310601a15f53715e5a6500  llvm-16.0.6--x86_64--debian-bullseye--linux.tar.xz

# Ubuntu 22.04 Jammy
cceb3d5ebb6935f072badb41b24698113c36af21fc648faa1db0c68a8139eda4  gcc-9.5.0--x86_64--ubuntu-jammy--linux.tar.xz
50c55f48c514bef15ef559c3a296d0e75e8bb16765edc8673725d7a3079b2a35  gcc-10.5.0--x86_64--ubuntu-jammy--linux.tar.xz
d58fb416807a93fd70e98594a9c17518d9acca558e03e30b08722b27165b70d1  gcc-11.4.0--x86_64--ubuntu-jammy--linux.tar.xz
fb6ab1166af0580a3b78b7bbec169e3ed2d95f92f14b81a6ed191ffa20a92f58  gcc-12.3.0--x86_64--ubuntu-jammy--linux.tar.xz
496f181ef1eb69325ec5b2d719d51ca3515de5c25b6c2beca637b2f626cfc499  gcc-13.2.0--x86_64--ubuntu-jammy--linux.tar.xz
1b5991d030fd1bacd9184ce53c9a5877fee9992fb0714281a93b4952f4c2da6c  llvm-12.0.1--x86_64--ubuntu-jammy--linux.tar.xz
e8249c990f05cab649097088ff170596c276221c228244376404f2249f55434a  llvm-13.0.1--x86_64--ubuntu-jammy--linux.tar.xz
673e8d534f56654edd3758afdad9052364ae7b1e9c2eb94219861ac3a190cdb6  llvm-14.0.6--x86_64--ubuntu-jammy--linux.tar.xz
625b51d13b3c3d2e9ea84d095dc121113905335c5d411e80f6735e0b3e8d30a7  llvm-15.0.7--x86_64--ubuntu-jammy--linux.tar.xz
d8ccb1d4841cb3c717cc00c7841b018a6db066211e6a41fbf064323d6cd5769a  llvm-16.0.6--x86_64--ubuntu-jammy--linux.tar.xz
"""

