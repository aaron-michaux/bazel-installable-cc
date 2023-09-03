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
# Debian Bullseye (10)
9efafe48b0a33f90f433efc6a51ef0e00e03dbf8e03c3802b4b41e5fdf041078  gcc-9.5.0--x86_64--bullseye--linux.tar.xz
f8ae6dc51ae2111fd4688df1d7f3d3592845b01ea95eadd2a59661aeeebf3b7a  gcc-10.5.0--x86_64--bullseye--linux.tar.xz
a5116ce97ab2cef4a6b06b6e8fc2fc7d6e518946a077ad56a1f92ef556ffecb1  gcc-11.4.0--x86_64--bullseye--linux.tar.xz
5c3303c7390214bf47cf5f1b11bf52b72af7adecf590b18f798f6b57307cd4da  gcc-12.3.0--x86_64--bullseye--linux.tar.xz
d3648a37a8facaf6babfe15c3009f4f40aea95cc0fdabe7f7072b50ae26a25dc  gcc-13.2.0--x86_64--bullseye--linux.tar.xz
0b864bbdb81ded47e6c52c7899d6d7ba492088ca503c1e738a8211551c4dc736  llvm-13.0.1--x86_64--bullseye--linux.tar.xz
5307697019eeca9a3d1945756a34b46c541f6688feb8bf9518005da51f98f049  llvm-14.0.6--x86_64--bullseye--linux.tar.xz
0ee49f7827c6c11c993f2c635348978c7b796fe6be9b2ab94db094830d41c777  llvm-15.0.7--x86_64--bullseye--linux.tar.xz
154ae8a6b651259be7015ebe217432a95cedf2ec676d759aaf0cf3632eb13bc4  llvm-16.0.6--x86_64--bullseye--linux.tar.xz

# Oracle Linux 8.8
6155053153b1a0a7d425e64657e35a660297c08d56bf59de9e3a2747331847b3  gcc-9.5.0--x86_64--ol8.8--linux.tar.xz
fa9633c8623b8c7c09b4ac07d99f9e6e3ae6664cebb3c5d062b32de9f8008fd6  gcc-10.5.0--x86_64--ol8.8--linux.tar.xz
3280ca5651c7408c29ab1d867da9524304580359df7f52df53fc46d21530e7a4  gcc-11.4.0--x86_64--ol8.8--linux.tar.xz
552b8be00b629d4f089cf10cb9f2fb2c45b204d99baa42acbd44071104954255  gcc-12.3.0--x86_64--ol8.8--linux.tar.xz
8c1989fca655473470e699cad4dc0023be1ad925eae3b1609049f3bf0109fcb2  gcc-13.2.0--x86_64--ol8.8--linux.tar.xz
b1325595248d0d4ce8eab671237f89d30c72e6b49b5541ea9fa230b0ee132734  llvm-13.0.1--x86_64--ol8.8--linux.tar.xz
0d129674527c0d28814b3910034a774aabdfed0a6d8ceab6b4bc49cb9d86a8ce  llvm-14.0.6--x86_64--ol8.8--linux.tar.xz
0f0e20587059dfa9a11d093a9e643d7e1d33bd3b7e579490352a9e97e2914183  llvm-15.0.7--x86_64--ol8.8--linux.tar.xz
e4233ff014ad9f9a0731b128cfbb611d9282432aa30c61e310fb3e6da689bb6f  llvm-16.0.6--x86_64--ol8.8--linux.tar.xz

# Ubuntu Jammy (22.04)
6532934d6cef2151177e4605eeff69d0da76373effd5777d3e72ae663d1c707a  gcc-9.5.0--x86_64--jammy--linux.tar.xz
6fd3ba60336e41f756915bdc872e71f793ea7b26bbdcbd91524e2899ee560a5d  gcc-10.5.0--x86_64--jammy--linux.tar.xz
5ad209026048dba15b2bff075677bab4c1c37fd7eac9efc1fb1b9511aae06f81  gcc-11.4.0--x86_64--jammy--linux.tar.xz
86bd62ee54816f86dbc93d5a6cf8031ba5d0444aaf4138cd03cbefdf46335920  gcc-12.3.0--x86_64--jammy--linux.tar.xz
28400cc1e2cf7bfcd649c443d0051f12c751833c0832d5975d7c1c9d324ea638  gcc-13.2.0--x86_64--jammy--linux.tar.xz
e7293756693fe323088c673594d36159fac74807aeb8bf50e48d849588cf2aba  llvm-13.0.1--x86_64--jammy--linux.tar.xz
a3f8e202cdc60f122c273e920aee0d46191716d14d6246a4118f22a9ff001993  llvm-14.0.6--x86_64--jammy--linux.tar.xz
5be71d27d6200d44da7cceba23a09f7f2c5b3a41697a461a1b5e1421ac1cf0ed  llvm-15.0.7--x86_64--jammy--linux.tar.xz
f86e8b4acac41ce5cc2dee355b626051fca7f72eff1c6e3b06748470146342e1  llvm-16.0.6--x86_64--jammy--linux.tar.xz
"""
