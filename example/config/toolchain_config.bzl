"""
Contains TWO parameters: URLs and MANIFEST
"""

# The list of URLs to attempt to download toolchains from
URLS = [
    "https://github.com/aaron-michaux/toolchains/releases/download/v0.1.0",
    # TODO, add additional backup URLs here
]

# (sha256 archive) pairs, specifying available toolchains, # lines ignored
# The "--" values in filename are necessary for parsing parts
#     <compiler>--<cpu>--<vendor>--<os>
MANIFEST = """
# Oracle Linux 8.8 (glibc 2.28)
721fbf86e9ab2e9b181cb32224d9e5e7e286c4452eadee5fc3e8f37af433bf79  gcc-9.5.0--x86_64--ol-8.8--linux.tar.xz
4078ed184cfb57dab01e70c4019491500a1ac38029ebb081a8f45c2af14f917d  gcc-10.5.0--x86_64--ol-8.8--linux.tar.xz
282000f5fd77f99f5c9cab822a12ef7676bce8166a50b78e62bb7b68f5ee7205  gcc-11.4.0--x86_64--ol-8.8--linux.tar.xz
43d5e5934572a95b437d17739a371769a9ca495d76af897d96fbeefbf4bd1132  gcc-12.3.0--x86_64--ol-8.8--linux.tar.xz
56c33f654398aaee3f78f0db598a6d254a23df482cd929e755bafdcd3fccccd8  gcc-13.2.0--x86_64--ol-8.8--linux.tar.xz
d74b158da9e9c818e679ee2ee645cbf0c2c5c182350712b8e7cd7afcd09cd893  llvm-12.0.1--x86_64--ol-8.8--linux.tar.xz
b3cc520704761cdf9298f0de6c66d5b8891fe896ed559f9280d87d24f1a8373b  llvm-13.0.1--x86_64--ol-8.8--linux.tar.xz
d097cc58537a43830c3597e35d14b7a685749d78423394433bc821a33116580b  llvm-14.0.6--x86_64--ol-8.8--linux.tar.xz
8267c6cb06db25f7abc6df9605e5016a2f532917d7531dad21db488465b39230  llvm-15.0.7--x86_64--ol-8.8--linux.tar.xz
6b895539758e91d2f5f030fca9a71215fd616f307aa3cc712049e21bafd9ef25  llvm-16.0.6--x86_64--ol-8.8--linux.tar.xz
dbb0ba2e31bba23e7bc1651569df957fdd700122c94a3f3a0790b2c5ce4b8d65  llvm-17.0.6--x86_64--ol-8.8--linux.tar.xz

# Debian 10 Bullseye (glibc 2.31)
c91730c311fa2b3044c474622ebf76ffb5fcbecf07aa82af25e60bc1d88fa468  gcc-9.5.0--x86_64--debian-bullseye--linux.tar.xz
fc4576571e3e8a81e03b40debe6e06f45cd028903f89520908d5ac34767c1535  gcc-10.5.0--x86_64--debian-bullseye--linux.tar.xz
775f9de7b4340c194b9cc24738939ed87c759c49425b122cbe53087ccaef57d8  gcc-11.4.0--x86_64--debian-bullseye--linux.tar.xz
484b3a36a9387a00c5c91eecba3165c0134224e2fd748f5f089e89d0e6d0a02c  gcc-12.3.0--x86_64--debian-bullseye--linux.tar.xz
8ea2b82c9700ce36f1455c39a87238ed63b5b334c7a487f7c6c59addf5a2512e  gcc-13.2.0--x86_64--debian-bullseye--linux.tar.xz
437cb1e5c418c1239745b740071da28b7b08858bea11b9b51230818de1d02da0  llvm-12.0.1--x86_64--debian-bullseye--linux.tar.xz
7c102145103c2d2a9b1cff1e5c17abcc45634d6e3c5190e4148d8c4922ba33aa  llvm-13.0.1--x86_64--debian-bullseye--linux.tar.xz
06e1bdabca51a22bd65bcfea17a617f1c0cc9de3cf952723fc582dfe80764f0d  llvm-14.0.6--x86_64--debian-bullseye--linux.tar.xz
07a4fee80f3e15b73ca431c915d1eca47a762b0d2cd7c2c26a47653ea384844f  llvm-15.0.7--x86_64--debian-bullseye--linux.tar.xz
9cb23068b38977688cc008a13f461356aa144b1d5eaedf1a995c656a93d65a29  llvm-16.0.6--x86_64--debian-bullseye--linux.tar.xz
84f3cf37b56dfd11b10a75d21390dd4011f2ec76b1be48148e16768fca5ad3bb  llvm-17.0.6--x86_64--debian-bullseye--linux.tar.xz

# Ubuntu 20.04 Focal (glibc 2.31)
c1d0b93fb77e6eb04df5851af2afe0e89ee567d7b2790abdffa3e1afc5ed1229  gcc-9.5.0--x86_64--ubuntu-focal--linux.tar.xz
d56939b42081f57b06df4edf8e847ed6f40b24e79ddb16913c52b6eb1eb2ca09  gcc-10.5.0--x86_64--ubuntu-focal--linux.tar.xz
9fbbe5705e23a18e5845a72acbcaefef2e25acf4ffba1b1c6a7fe49a49c29ab4  gcc-11.4.0--x86_64--ubuntu-focal--linux.tar.xz
4346b2db9528b81c30910227acf41ed5a2e7fd9f4c23fb57027fd3b1a4e6c55d  gcc-12.3.0--x86_64--ubuntu-focal--linux.tar.xz
504a1a19eaca32b4a7022b8a8d6ead724bcb3f5a5ded453e5586342cd83878f1  gcc-13.2.0--x86_64--ubuntu-focal--linux.tar.xz
64643fcdb68716a17786433ad3ff480f04a93347fe594c97e958416d524bdf21  llvm-12.0.1--x86_64--ubuntu-focal--linux.tar.xz
43b5a350d8b426bbfe484f3849fe2c766d97bf0762d8b4cb1632d43197a8d4e6  llvm-13.0.1--x86_64--ubuntu-focal--linux.tar.xz
64733147042bc6ea8fabc926587fe23a42c02fa777065656e90bd05ec86166dc  llvm-14.0.6--x86_64--ubuntu-focal--linux.tar.xz
6ed35229045ea20d3ca736c4443e5f35e2629a8bbc36f25253586b97293d3c63  llvm-15.0.7--x86_64--ubuntu-focal--linux.tar.xz
e06cd782c809a062c099e4705f2ba0768e1b133a68e17d7ea4b3dd5d065358f9  llvm-16.0.6--x86_64--ubuntu-focal--linux.tar.xz
f57d1f3979c0a8baf4dee1397904f8bade58daa45c1180a7c29d8d618b98af56  llvm-17.0.6--x86_64--ubuntu-focal--linux.tar.xz

# Ubuntu 22.04 Jammy (glibc 2.35)
cceb3d5ebb6935f072badb41b24698113c36af21fc648faa1db0c68a8139eda4  gcc-9.5.0--x86_64--ubuntu-jammy--linux.tar.xz
50c55f48c514bef15ef559c3a296d0e75e8bb16765edc8673725d7a3079b2a35  gcc-10.5.0--x86_64--ubuntu-jammy--linux.tar.xz
d58fb416807a93fd70e98594a9c17518d9acca558e03e30b08722b27165b70d1  gcc-11.4.0--x86_64--ubuntu-jammy--linux.tar.xz
fb6ab1166af0580a3b78b7bbec169e3ed2d95f92f14b81a6ed191ffa20a92f58  gcc-12.3.0--x86_64--ubuntu-jammy--linux.tar.xz
496f181ef1eb69325ec5b2d719d51ca3515de5c25b6c2beca637b2f626cfc499  gcc-13.2.0--x86_64--ubuntu-jammy--linux.tar.xz
8cf74c84d4212b7747fe0af87d879517a168a037e38570be26a0b361d37a38d9  llvm-12.0.1--x86_64--ubuntu-jammy--linux.tar.xz
ba5c34697a3db958156b4cfe5e5ef6adf72852bd1fd5062ceacceecdaf618613  llvm-13.0.1--x86_64--ubuntu-jammy--linux.tar.xz
2c4ac74ad04675c8693856297815b26fa68db507c6821745102600d42efc5f28  llvm-14.0.6--x86_64--ubuntu-jammy--linux.tar.xz
6a000cdf97bc7010c392db3ea7a8ce0e6b4d01d3857af3a41a5827234ece658b  llvm-15.0.7--x86_64--ubuntu-jammy--linux.tar.xz
dc0a509dcba2a997958ca91f86c53b69a8c3dd73a2c3a9835fb09f34dc0e703e  llvm-16.0.6--x86_64--ubuntu-jammy--linux.tar.xz
580f34fe78d9a6699d9b191696d5f7e5ab749dee3af4faafa9b336f5c3f5ba88  llvm-17.0.6--x86_64--ubuntu-jammy--linux.tar.xz
"""
