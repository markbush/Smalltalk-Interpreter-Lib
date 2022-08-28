# Smalltalk Interpreter Lib

This repository is a Smalltalk-80 interpreter written in Swift.

It is able to read image and snapshot files from the original Smalltalk-80 system.

The interpreter is an exact replica in Swift of the reference implementation from the Blue Book (["Smalltalk-80 The Language and it's Implementation"](https://rmod-files.lille.inria.fr/FreeBooks/BlueBook/Bluebook.pdf)).

The object model is not the same as in the Blue Book.  The reference implementation uses 16 bit words which restricts the number of available object pointers to 32767 (odd numbered object pointers represent integers for performance and object pointer "0" is an illegal pointer).  Also, the original object table representation restricts memory to, at most, 16 segments of 65536 words (2MB).

The object model presented here uses 32 bit words.  Class and method headers retain their original structure with the 16 bits in the low half of the word.  Bytes of methods are packed 4 bytes to a word.  Further, instead of using an allocated chunk of memory and manually managing free memory lists, this implementation uses a Swift dictionary keyed by object pointer.
