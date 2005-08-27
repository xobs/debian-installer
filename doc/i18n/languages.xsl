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
<table border="1">
<tr>
<th>Code</th>
<th>Language</th>
<th>Initial steps</th><th>Coordinator</th>
<th>Backup Coordinator</th>
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
<xsl:if test="string-length(@coord_name)">
	<xsl:value-of select="@coord_name"/>
</xsl:if>
</td>
<td>
<xsl:if test="string-length(@bkp_coord_name)">
	<xsl:value-of select="@bkp_coord_name"/>
</xsl:if>
</td>
<td><xsl:value-of select="@team_repository"/></td>
</tr>
</xsl:template>
</xsl:transform>
