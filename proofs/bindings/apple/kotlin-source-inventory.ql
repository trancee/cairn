/**
 * @name Compiled Kotlin source inventory
 * @description Source compilation units for the required Cairn coverage gate.
 * @kind metric
 * @id cairn/compiled-kotlin-source-inventory
 * @tags cairn-coverage
 */

import java

from CompilationUnit source
where source.fromSource() and source.isKotlinSourceFile()
select source.getAbsolutePath(), source.getNumberOfLinesOfCode()
