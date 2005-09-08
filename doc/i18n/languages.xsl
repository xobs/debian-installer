<?xml version="1.0"?>
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output method="html"/>

<xsl:template match="language_entries">
<html>
<head>
<title>Debian-Installer Translators</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
</head>
<body>
  <p>The following table lists all <a href="http://www.debian.org/devel/debian-installer">Debian Installer</a> translators.</p>
  <p>Current number of fully supported languages: <xsl:value-of select="count(//language_entry[@supported = 'true'])"/></p>
  <p>Total number of languages in the table: <xsl:value-of select="count(//language_entry)"/></p>
  <p>D-I now supports <xsl:value-of select="sum(//@speakers[../@supported = 'true']) div 6459821923 * 100"/>% of world population.</p>
  <p>With future languages, D-I will support <xsl:value-of select="sum(//@speakers) div 6459821923 * 100"/>% of world population.</p>
<table border="1">
<tr>
<th>Code</th>
<th>Language</th>
<th>Supported</th>
<th>Coordinator</th>
<th>Backup Coordinator</th>
<th>Number of Speakers (Ethnologue)</th>
<th>Number of Speakers (Ethnologue <em>corrected</em>)</th>
<th>Repository</th>
</tr>
<xsl:apply-templates/>
</table>
</body>
</html>
</xsl:template>

<xsl:template match="language_entry">
<tr>
<td><xsl:value-of select="@code"/></td>
<xsl:choose>
	<xsl:when test="string-length(@team_email)">
		<td><a href="mailto:{@team_email}"><xsl:value-of select="@english_name"/></a></td>
	</xsl:when>
	<xsl:otherwise>
		<td><xsl:value-of select="@english_name"/></td>
	</xsl:otherwise>
</xsl:choose>
<td>
<xsl:choose>
	<xsl:when test="@supported = 'true'">
		SUPPORTED
	</xsl:when>
	<xsl:otherwise>
		<xsl:value-of select="@nlp_step"/>&#160;
	</xsl:otherwise>
</xsl:choose>
</td>
<td>
<xsl:if test="string-length(@coord_name)">
	<xsl:value-of select="@coord_name"/>
</xsl:if>
&#160;
</td>
<td>
<xsl:if test="string-length(@bkp_coord_name)">
	<xsl:value-of select="@bkp_coord_name"/>
</xsl:if>
&#160;
</td>
<td><xsl:value-of select="@speakers"/>&#160;</td>
<td><xsl:value-of select="@speakers_corr"/>&#160;</td>
<td><xsl:value-of select="@team_repository"/>&#160;</td>
</tr>
  <p>The number of speakers per language comes from data by: <strong>Gordon,
     Raymond G., Jr. (ed.), 2005.</strong> <em>Ethnologue: Languages of the World, Fifteenth
     edition.</em> Dallas, Tex.: SIL International. Online version:
     <a href="http://www.ethnologue.com/">http://www.ethnologue.com/</a>.</p>
  <p>The second number of speakers are data by Ethnologue <em>corrected</em>
by Debian Installer developers when they feel Ethnologue data to be
inaccurate. Ethnologue often focuses on native speakers of a given language
which often minimizes the number of speakers of that language.</p>
<!-- World population counter comes from www.geohive.com as of 2005-09-05 -->
</xsl:template>
</xsl:transform>
