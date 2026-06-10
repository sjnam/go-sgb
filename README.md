# go-sgb

A Go port of Donald Knuth's
[Stanford GraphBase](https://www-cs-faculty.stanford.edu/~knuth/sgb.html)
(SGB) — a collection of data sets and subroutines for graph algorithms and
combinatorics.

## Overview

The Stanford GraphBase is a library of programs for generating and examining
a wide variety of graphs and data structures. This repository is a faithful,
idiomatic Go port of the SGB C/CWEB sources.

## Packages

### Core

| Package | SGB Module | Description |
| ------- | ---------- | ----------- |
| `graph` | GB_GRAPH | Core data structures: `Vertex`, `Arc`, `Graph` |
| `basic` | GB_BASIC | Graph generators and transformers |
| `flip` | GB_FLIP | Subtractive RNG (period 2⁸⁵ − 2³⁰) |
| `rand` | GB_RAND | Random graph generator |
| `io` | GB_IO | File I/O with checksum validation for `.dat` files |
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

## Demos

The `demos/` directory contains Go ports of Knuth's demo programs:

### `ladders`

Finds shortest word ladders between five-letter English words using
Dijkstra's algorithm. Supports alphabetic distance, frequency-based
distance, and A\*-style heuristic.

```text
go run ./demos/ladders/
Starting word: chaos
    Goal word: order
chaos -> chaps -> ... -> order
```

### `football`

Finds long chains of college football scores to "prove" one team outranks
another. Width=0 uses a greedy algorithm; higher widths use a stratified
heuristic.

```text
go run ./demos/football/
Starting team: Stanford
   Other team: Harvard
 Oct 06: Stanford Cardinal 36, Notre Dame Fighting Irish 31 (+5)
 ...
 Nov 17: Yale Bulldogs 34, Harvard Crimson 19 (+781)
```

### `word_components`

Computes connected components of the five-letter word graph, printing
statistics as each vertex is added (union-find algorithm).

```text
go run ./demos/word_components/
```

### `book_components`

Computes biconnected components of character-encounter graphs from classic
literature using the Hopcroft–Tarjan algorithm.

```text
go run ./demos/book_components/ -tanna
```

### `roget_components`

Computes strongly connected components of the Roget thesaurus graph using
Tarjan's iterative depth-first-search algorithm. Components are printed in
reverse topological order.

```text
go run ./demos/roget_components/
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

## Requirements

- Go 1.21 or later

## Installation

```bash
git clone https://github.com/sjnam/go-sgb
cd go-sgb
go build ./...
```

## Running Demos

```bash
go run ./demos/ladders/
go run ./demos/football/ [searchwidth]
go run ./demos/word_components/
go run ./demos/book_components/ [-tTITLE]
go run ./demos/roget_components/
```

## Reference

- Donald E. Knuth, *The Stanford GraphBase: A Platform for Combinatorial
  Computing*, ACM Press, 1993.
- Source: <https://www-cs-faculty.stanford.edu/~knuth/sgb.html>
