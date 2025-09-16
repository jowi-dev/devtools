j: j.ml
	PATH="$$(mise env --shell=bash | grep PATH | cut -d= -f2 | tr -d '"'):$$PATH" ocamlopt -I +unix unix.cmxa -o j j.ml
