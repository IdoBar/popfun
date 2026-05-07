#!/usr/bin/env nextflow
nextflow.enable.dsl = 2
include { POPFUN } from './workflows/popfun'
workflow { POPFUN() }
