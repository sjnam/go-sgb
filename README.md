# go-sgb

A Go port of Donald Knuth's
[Stanford GraphBase](https://www-cs-faculty.stanford.edu/~knuth/sgb.html)
(SGB) — a collection of data sets and subroutines for graph algorithms and
combinatorics.

## Overview

The Stanford GraphBase is a library of programs for generating and examining
a wide variety of graphs and data structures. This repository is a faithful,
idiomatic Go port of the SGB C/CWEB sources.

The GB_FLIP random number generator is ported bit-for-bit, so every generator
produces exactly the same graphs as the original C library for the same
parameters and seeds — same vertices, same edges, same ID strings.

## Packages

### Core

| Package | SGB Module | Description |
| ------- | ---------- | ----------- |
| `graph` | GB_GRAPH | Core data structures: `Vertex`, `Arc`, `Graph` |
| `basic` | GB_BASIC | Graph generators and transformers |
| `flip` | GB_FLIP | Subtractive RNG (period 2⁸⁵ − 2³⁰) |
| `rand` | GB_RAND | Random graph generator |
| `gbio` | GB_IO | File I/O with checksum validation for `.dat` files |
| `save` | GB_SAVE | Serialize/deserialize graphs to/from `.gb` files |
| `dijk` | GB_DIJK | Dijkstra shortest-path with pluggable priority queue |
| `sort` | GB_SORT | Radix sort utility for linked lists |

### Graph Generators

| Package | SGB Module | Description |
| ------- | ---------- | ----------- |
| `words` | GB_WORDS | Five-letter word graph (one-letter-difference edges) |
| `roget` | GB_ROGET | Directed graph from Roget's 1879 Thesaurus |
| `books` | GB_BOOKS | Character-encounter graphs from classic literature |
| `games` | GB_GAMES | 1990 college football season game graph |
| `miles` | GB_MILES | Highway mileage graph between 128 North American cities |
| `econ` | GB_ECON | U.S. input/output economic flow graph (1985 data) |
| `gates` | GB_GATES | Boolean circuit graphs |
| `lisa` | GB_LISA | Pixel-intensity graph from the Mona Lisa image |
| `plane` | GB_PLANE | Planar graphs via Delaunay triangulation |
| `raman` | GB_RAMAN | Ramanujan expander graphs |

## Quick Start

Generators read their data files relative to `gbio.DataDirectory`, so set it
before the first call. The example below builds the five-letter word graph
and finds a shortest word ladder with Dijkstra's algorithm:

```go
package main

import (
    "fmt"
    "os"

    "github.com/sjnam/go-sgb/dijk"
    "github.com/sjnam/go-sgb/gbio"
    "github.com/sjnam/go-sgb/words"
)

func main() {
    // Tell the generators where the .dat files live.
    gbio.DataDirectory = "data/"

    // Build the five-letter word graph (all 5757 qualifying words).
    g, index, err := words.Words(0, nil, 0, 0)
    if err != nil {
        panic(err)
    }
    fmt.Printf("%s: %d vertices, %d edges\n", g.ID, g.N, g.M/2)

    // Find the shortest word ladder from "words" to "graph".
    start := index.FindWord("words", nil)
    goal := index.FindWord("graph", nil)
    if d := dijk.Dijkstra(start, goal, g, nil, nil, nil); d >= 0 {
        dijk.PrintDijkstraResult(os.Stdout, goal)
    }
}
```

Output:

```text
words(5757,0,0,0): 5757 vertices, 14135 edges
         0 words
         1 wolds
         2 golds
         3 goads
         4 grads
         5 grade
         6 grape
         7 graph
```

## Demos

The `demos/` directory contains Go ports of Knuth's demo programs.

### `ladders`

Finds shortest word ladders between five-letter English words using
Dijkstra's algorithm.

```text
$ go run ./demos/ladders/
Starting word: chaos
    Goal word: order
         0 chaos
         1 choos
         2 chops
         ⋮
        11 odder
        12 order
```

Options: `-v` (trace the search), `-a` (alphabetic distance), `-f`
(frequency-based distance), `-h` (A\*-style lower-bound heuristic),
`-e` (echo input), `-nN` (N most common words), `-rN` (N random words),
`-sN` (random seed), `-dDIR` (data directory).

### `football`

Finds long chains of college football scores to "prove" one team outranks
another. With no argument a simple greedy algorithm is used; `football N`
keeps the N best partial chains per stratum of a stratified heuristic and
tends to find much longer chains — Stanford over Harvard by 781 points with
the greedy algorithm, 1895 with width 10, 2185 with width 4000.

```text
$ go run ./demos/football/ [searchwidth]
Starting team: Stanford
   Other team: Harvard
 Sep 22: Stanford Cardinal 37, Oregon State Beavers 3 (+34)
 Oct 13: Oregon State Beavers 35, Arizona Wildcats 21 (+48)
 ⋮
 Nov 17: Yale Bulldogs 34, Harvard Crimson 19 (+781)
```

### `word_components`

Computes connected components of the five-letter word graph, printing
statistics as each vertex is added (union-find algorithm).

```text
go run ./demos/word_components/ [-dDIR]
```

### `book_components`

Computes biconnected components of character-encounter graphs from classic
literature using the Hopcroft–Tarjan algorithm.

```text
go run ./demos/book_components/ [-tTITLE] [-nN] [-xN] [-fN] [-lN] [-iN] [-oN] [-sN] [-v] [-gFILE] [-dDIR]
```

`TITLE` is one of `anna` (default), `david`, `jean`, `huck`, or `homer`.

### `roget_components`

Computes strongly connected components of the Roget thesaurus graph using
Tarjan's iterative depth-first-search algorithm. Components are printed in
reverse topological order.

```text
go run ./demos/roget_components/ [-nN] [-dN] [-pN] [-sN] [-gFILE] [-DDIR]
```

## Data Files

The `data/` directory contains the `.dat` files required by the graph
generators:

- `words.dat` — five-letter English words with frequency data
- `roget.dat` — Roget's Thesaurus cross-references
- `anna.dat`, `david.dat`, `jean.dat`, `huck.dat`, `homer.dat` —
  literary character data
- `games.dat` — 1990 college football scores
- `miles.dat` — North American city mileage data
- `econ.dat` — U.S. economic input/output data
- `lisa.dat` — Mona Lisa pixel data

Generators look for these files in the current directory first, then under
`gbio.DataDirectory`. Every file carries line counts and checksums that are
verified on read.

## Porting Notes

The port keeps Knuth's algorithms and data layouts intact while replacing
C idioms with Go ones:

- **Errors instead of panic codes.** The C library reports failures through
  a global `panic_code`; here every generator returns
  `(*graph.Graph, error)` with sentinel errors (`graph.ErrBadSpecs`,
  `graph.ErrSyntaxError`, …) that work with `errors.Is`.
- **Auxiliary data is returned, not stored in globals.** `words.Words`
  returns a `*words.Index` for word lookup, `miles.Miles` returns a
  `*miles.DistanceMatrix`, `books.Book` returns the chapter-name list, and
  `gates.RunRisc` returns the machine state. Calls are independent and
  reentrant.
- **Boolean parameters are `bool`.** C's `long` flags (`directed`, `self`,
  `copy`, …) become `bool`; integers remain only for bitmasks, enums, and
  genuinely ternary values. Graph ID strings still render flags as `0`/`1`,
  so IDs match the C originals exactly.
- **Utility fields.** The C `util` unions become `any`-typed fields
  (`Vertex.U`–`Z`, `Arc.A`/`B`, `Graph.UU`–`ZZ`); each package provides
  typed accessor functions, and the 14-character `UtilTypes` convention is
  preserved for `save`/`restore`.
- **Memory management is the garbage collector's job.** `gb_recycle` and
  friends are no-ops; there is no `Area` bookkeeping.
- **Diagnostic output goes to an `io.Writer`.** Functions like
  `dijk.Dijkstra` (trace), `dijk.PrintDijkstraResult`, and
  `gates.PrintGates` take a writer instead of printing to stdout.
- **GB_IO is package `gbio`** to avoid clashing with the standard library's
  `io` package.

The original CWEB sources (© 1993 Stanford University) are included in the
`sources/` directory for reference and comparison.

## Testing

```bash
go test ./...
```

The tests exercise every module against invariants documented in the CWEB
sources: the word graph has exactly 5757 vertices, *Anna Karenina* has 239
chapters, the mileage data satisfies the triangle inequality, the football
demo reproduces Knuth's published chain totals, and save/restore round-trips
preserve graphs exactly.

## Requirements

- Go 1.26 or later

## Installation

```bash
git clone https://github.com/sjnam/go-sgb
cd go-sgb
go build ./...
```

## Reference

- Donald E. Knuth, *The Stanford GraphBase: A Platform for Combinatorial
  Computing*, ACM Press, 1993.
- Source: <https://www-cs-faculty.stanford.edu/~knuth/sgb.html>
