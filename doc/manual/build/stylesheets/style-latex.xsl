<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">

<!-- Include common profiling stylesheet -->
<xsl:import href="/usr/share/xml/docbook/stylesheet/db2latex/latex/docbook.xsl"/>

<!-- Generate DocBook instance with correct DOCTYPE -->
<xsl:output method="xml" encoding="UTF-8"/>
<xsl:param name="latex.fontenc">T1,T2A</xsl:param>
<xsl:param name="latex.inputenc">utf8</xsl:param>
</xsl:stylesheet>

