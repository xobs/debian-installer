<?xml version='1.0'?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

<xsl:output encoding="UTF-8"/>
<xsl:param name="latex.inputenc">utf8</xsl:param>
<xsl:variable name="latex.use.ucs">1</xsl:variable>
<xsl:param name="latex.fontenc">T1</xsl:param>
<xsl:param name="latex.book.preamble.post.l10n">
    <xsl:text>\renewcommand{\rmdefault}{pnc}</xsl:text>
    <xsl:text>\renewcommand{\sfdefault}{phv}</xsl:text>
</xsl:param>
</xsl:stylesheet>
