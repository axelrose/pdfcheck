<?xml version="1.0" encoding="UTF-8"?>

<!-- Version 104 -->
<!-- Icons for PDF document, Info, Warning and Error -->

<!-- Version 103 -->
<!-- Zeit der Prüfung aus Node I2InfoDate im Kopf des Reports -->
<!-- XSL-Version als HTML Kommentar -->

<!-- Version 102 -->
<!-- geänderter HTML Kopf -->
<!-- Auflistung der Auszüge mit Komma getrennt -->

<!-- Version 101 -->
<!-- Info pro Seite, auch wenn keiner Hit erzeugt wurde -->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html" doctype-public="-//W3C//DTD HTML 4.01 Transitional//EN"/>

	<xsl:variable name="newline">
		<xsl:text>
		</xsl:text>
	</xsl:variable>

	<xsl:key name="Rules" match="RuleInfr" use="Value"/>

	<xsl:template match="/">
		<!-- Output Html header information -->
		<xsl:comment> Version 103, 18.12.2006, Peter Kleinheider </xsl:comment>
		<html>
			<head>
				<meta http-equiv="content-type" content="text/html; charset=utf-8"/>
				<title>PDF CHECK REPORT</title>
				<xsl:call-template name="css"/>
			</head>
			<body>

				<xsl:call-template name="html_body"/>

				<xsl:choose>
					<xsl:when test="count(*/Problems/Page)  &gt; 0">
						<xsl:apply-templates select="*/Problems"/>
					</xsl:when>

					<xsl:otherwise>
						<h2><xsl:call-template name="OKIMG"/> No irregularities where found during the preflight check</h2>
					</xsl:otherwise>


				</xsl:choose>

				<h2>Information per page</h2>
				<xsl:apply-templates select="*/Pages/Page"/>


			</body>
		</html>
	</xsl:template>

	<!-- CSS -->

	<xsl:template name="css">
		<style type="text/css"><xsl:text>
		</xsl:text>
			<xsl:comment>
				
				.headline {
				font-family: Verdana, Arial, Helvetica, sans-serif;
				font-size: 14px;
				font-weight: bold;
				color: #0076A3;
				}
				.subline {
				font-family: Verdana, Arial, Helvetica, sans-serif;
				font-size: 10px;
				font-weight: bold;
				background-color: #381A18;
				color: #FFFFFF;
				}
				.copy {
				font-family: Verdana, Arial, Helvetica, sans-serif;
				font-size: 10px;
				color: #000000;
				}
				.Stil3 {font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 10px; color: #666666; }
				a:link {
				color: #666666;
				text-decoration: none;
				}
				a:visited {
				text-decoration: none;
				color: #666666;
				}
				a:hover {
				text-decoration: none;
				color: #666666;
				}
				a:active {
				text-decoration: none;
				color: #666666;
				}
				.even { font-family: Verdana, Arial, Helvetica, sans-serif;
				font-size: 11px;
				}
				.odd { font-family: Verdana, Arial, Helvetica, sans-serif;
				font-size: 11px;
				}
				.infohead { color:#0033FF }
				.errhead  { color:#FF0000 }
				.warnhead { color:#FF6600 }
				.white    { color:#FFFFFF }
				
			</xsl:comment><xsl:text>
			</xsl:text>
			
		</style>

	</xsl:template>

	<!-- Body -->

	<xsl:template name="html_body">
		<h1>PDF Preflight Report</h1>
		
		<table width="90%" border="0" cellpadding="3" cellspacing="0">

			<tr>
				<td colspan="2" class="headline"><xsl:call-template name="PDFIMG"/> checked PDF file: 
					<xsl:value-of select="//FSFile/Value"/>
				</td>
			</tr>

			<tr class="subline">
				<td width="5" colspan="2">Information | PDF check profile: <xsl:value-of select="//UsedProfile/Value"/> | <xsl:value-of select="//I2InfoDate/Value"/></td>
			</tr>

			<tr>
				<td>Version</td>
				<td>
					<xsl:value-of select="//PDFVersion"/>
				</td>
			</tr>
			<xsl:if test="//Pages/Page">
				<tr>
					<td>Page count</td>
					<td>
						<xsl:value-of
							select="count(//Pages/Page[@type=&quot;Integer&quot;])"/>
					</td>
				</tr>
			</xsl:if>
			<tr>
				<td>PDF Producer</td>
				<td>
					<xsl:value-of select="//Producer"/>
				</td>
			</tr>
			<tr>
				<td>Application</td>
				<td>
					<xsl:value-of select="//Creator"/>
				</td>
			</tr>
			<tr>
				
				
				<td>Separations (<xsl:value-of select="//Plates/PlatesNumber/Value"/>)</td>
				<td>
					<xsl:call-template name="GetPlateName">
						<xsl:with-param name="stringIn" select="//Plates/PlatesName/Value"/>
					</xsl:call-template>
				</td>
			</tr>
			<xsl:if test="/descendant-or-self::PSName">
				<tr>
					<td valign="top">Font list</td>
					<td valign="top">
						<xsl:for-each select="//Overview/Fonts/Font/PSName">
							<xsl:sort select="Value" order="ascending"/>
							<xsl:sort select="PSName/Value"/>
							<xsl:value-of select="Value"/>
							<xsl:text>, </xsl:text>
						</xsl:for-each>
						
					</td>
				</tr>
			</xsl:if>
			<xsl:if test="/descendant-or-self::OutputIntent">
				<tr>
					<td valign="top">Output Intent</td>
					<td valign="top">
						<xsl:value-of select="//Overview/OutputIntents/OutputIntent/Value"/>
						<xsl:text> </xsl:text>
					</td>
				</tr>
			</xsl:if>
			<xsl:if test="/descendant-or-self::PDFXVersion">
				<tr>
					<td valign="top">Standard: </td>
					<td valign="top">
						<xsl:value-of select="//PDFXVersion/Value"/>
						<xsl:text> </xsl:text>
					</td>
				</tr>
			</xsl:if>

		</table>
	</xsl:template>


	<!-- Errorlist -->

	<!-- Generate the problems section -->
	<xsl:template match="Problems">

		<h2>List of hits in the complete document</h2>
		<p>Hits generated running the preflight profile:</p>

		<xsl:if
			test="count(/descendant-or-self::RuleInfr[@severity=&quot;error&quot;]) &gt; 0">

			<xsl:call-template name="addSeverityTable">
				<xsl:with-param name="severity" select="'error'"/>
				<xsl:with-param name="node"
					select="/descendant-or-self::RuleInfr[@severity=&quot;error&quot;]"/>

			</xsl:call-template>
		</xsl:if>

		<xsl:if
			test="count(/descendant-or-self::RuleInfr[@severity=&quot;warning&quot;]) &gt; 0">

			<xsl:call-template name="addSeverityTable">
				<xsl:with-param name="severity" select="'warning'"/>
				<xsl:with-param name="node"
					select="/descendant-or-self::RuleInfr[@severity=&quot;warning&quot;]"/>

			</xsl:call-template>
		</xsl:if>

		<xsl:if
			test="count(/descendant-or-self::RuleInfr[@severity=&quot;info&quot;]) &gt; 0">

			<xsl:call-template name="addSeverityTable">
				<xsl:with-param name="severity" select="'info'"/>
				<xsl:with-param name="node"
					select="/descendant-or-self::RuleInfr[@severity=&quot;info&quot;]"/>

			</xsl:call-template>
		</xsl:if>

	</xsl:template>


	<xsl:template match="*/Pages/Page">
		<xsl:variable name="page" select="Value"/>

		<xsl:call-template name="addPageInfo">
			<xsl:with-param name="pagenumber" select="Value"/>
		</xsl:call-template>

		<xsl:variable name="lastValue" select="Value"/>

		<xsl:apply-templates select="*/Problems/Page[Value=$lastValue]"/>

		<xsl:call-template name="addPageProblemsTable">
			<xsl:with-param name="node" select="//Problems/Page[Value=$lastValue]"/>
		</xsl:call-template>
	</xsl:template>

	<!-- Generate the problems section -->
	<xsl:template name="addPageProblemsTable">

		<xsl:param name="node" select="//Problems/Page"/>

		<xsl:if test="$node">

			<xsl:variable name="page" select="$node[Value]"/>


			<!-- <p>Folgende Treffer wurden beim Ausführen des Prüfprofils generiert:</p> -->

			<xsl:if test="count($node/RuleInfr[@severity=&quot;error&quot;]) &gt; 0">

				<xsl:call-template name="addSeverityTable">
					<xsl:with-param name="severity" select="'error'"/>
					<xsl:with-param name="node"
						select="$node/RuleInfr[@severity=&quot;error&quot;]"/>
					<xsl:with-param name="perpage" select="'1'"/>
				</xsl:call-template>
			</xsl:if>
			<xsl:if
				test="count($node/PageInfo/descendant::RuleInfr[@severity=&quot;error&quot;]) &gt; 0">

				<xsl:call-template name="addSeverityTable">
					<xsl:with-param name="severity" select="'error'"/>
					<xsl:with-param name="perpage" select="'1'"/>

					<xsl:with-param name="node"
						select="$node/PageInfo/descendant::RuleInfr[@severity=&quot;error&quot;]"
					/>
				</xsl:call-template>
			</xsl:if>

			<xsl:if test="count($node/RuleInfr[@severity=&quot;warning&quot;]) &gt; 0">

				<xsl:call-template name="addSeverityTable">
					<xsl:with-param name="severity" select="'warning'"/>
					<xsl:with-param name="node"
						select="$node/RuleInfr[@severity=&quot;warning&quot;]"/>
					<xsl:with-param name="perpage" select="'1'"/>
				</xsl:call-template>
			</xsl:if>
			<xsl:if
				test="count($node/PageInfo/descendant::RuleInfr[@severity=&quot;warning&quot;]) &gt; 0">

				<xsl:call-template name="addSeverityTable">
					<xsl:with-param name="severity" select="'warning'"/>
					<xsl:with-param name="perpage" select="'1'"/>

					<xsl:with-param name="node"
						select="$node/PageInfo/descendant::RuleInfr[@severity=&quot;warning&quot;]"
					/>
				</xsl:call-template>
			</xsl:if>

			<xsl:if test="count($node/RuleInfr[@severity=&quot;info&quot;]) &gt; 0">

				<xsl:call-template name="addSeverityTable">
					<xsl:with-param name="severity" select="'info'"/>
					<xsl:with-param name="perpage" select="'1'"/>

					<xsl:with-param name="node"
						select="$node/RuleInfr[@severity=&quot;info&quot;]"/>
				</xsl:call-template>
			</xsl:if>
			<xsl:if
				test="count($node/PageInfo/descendant::RuleInfr[@severity=&quot;info&quot;]) &gt; 0">

				<xsl:call-template name="addSeverityTable">
					<xsl:with-param name="severity" select="'info'"/>
					<xsl:with-param name="perpage" select="'1'"/>

					<xsl:with-param name="node"
						select="$node/PageInfo/descendant::RuleInfr[@severity=&quot;info&quot;]"
					/>
				</xsl:call-template>
			</xsl:if>

		</xsl:if>

	</xsl:template>

	<xsl:template name="addPageInfo">
		<xsl:param name="node" select="//Pages"/>
		<xsl:param name="pagenumber" select="1"/>
		<table width="90%" border="0" cellpadding="3" cellspacing="0">

			<tr>
				<td colspan="2" class="headline">
					<xsl:text>Page </xsl:text>
					<xsl:value-of select="$pagenumber"/>
				</td>
			</tr>

			<tr class="subline">
				<td width="5" colspan="2">Information</td>
			</tr>
			<xsl:if
				test="$node/Page[Value=$pagenumber]/PageInfo/MediaBox">
				<tr class="copy">
					<td>Media box (pt)</td>
					<td>
						<xsl:value-of
							select="round(number($node/Page[Value=$pagenumber]/PageInfo/MediaBox/Fixed[3]/Value))"/>
						<xsl:text>pt / </xsl:text>
						<xsl:value-of
							select="round(number($node/Page[Value=$pagenumber]/PageInfo/MediaBox/Fixed[4]/Value))"/>
						<xsl:text>pt</xsl:text>
					</td>
				</tr>
			</xsl:if>
			
			<xsl:if test="$node/Page[Value=$pagenumber]/PageInfo/TrimBox/Fixed/Value">
				
				<tr class="copy">
					<td>Trim box (pt)</td>
					<td>
						<xsl:value-of
							select="round((number($node/Page[Value=$pagenumber]/PageInfo/TrimBox/Fixed[3]/Value) - number($node/Page[Value=$pagenumber]/PageInfo/TrimBox/Fixed/Value)))"/>
						<xsl:text>pt / </xsl:text>
						<xsl:value-of
							select="round((number($node/Page[Value=$pagenumber]/PageInfo/TrimBox/Fixed[4]/Value) - number($node/Page[Value=$pagenumber]/PageInfo/TrimBox/Fixed[2]/Value)))"/>
						<xsl:text>pt (</xsl:text>
						<xsl:text>Shift: </xsl:text>
						<xsl:value-of
							select="round(number($node/Page[Value=$pagenumber]/PageInfo/TrimBox/Fixed/Value))"/>
						<xsl:text>pt / </xsl:text>
						<xsl:value-of
							select="round(number($node/Page[Value=$pagenumber]/PageInfo/TrimBox/Fixed[2]/Value))"/>
						<xsl:text>pt)</xsl:text>
					</td>
				</tr>
				
			</xsl:if>

			<xsl:if test="$node/Page[Value=$pagenumber]/PageInfo/CropBox/Fixed/Value">

				<tr class="copy">
					<td>Crop box (pt)</td>
					<td>
						<xsl:value-of
							select="round((number($node/Page[Value=$pagenumber]/PageInfo/CropBox/Fixed[3]/Value) - number($node/Page[Value=$pagenumber]/PageInfo/CropBox/Fixed/Value)))"/>
						<xsl:text>pt / </xsl:text>
						<xsl:value-of
							select="round((number($node/Page[Value=$pagenumber]/PageInfo/CropBox/Fixed[4]/Value) - number($node/Page[Value=$pagenumber]/PageInfo/CropBox/Fixed[2]/Value)))"/>
						<xsl:text>pt (</xsl:text>
						<xsl:text>Shift: </xsl:text>
						<xsl:value-of
							select="round(number($node/Page[Value=$pagenumber]/PageInfo/CropBox/Fixed/Value))"/>
						<xsl:text>pt / </xsl:text>
						<xsl:value-of
							select="round(number($node/Page[Value=$pagenumber]/PageInfo/CropBox/Fixed[2]/Value))"/>
						<xsl:text>pt)</xsl:text>
					</td>
				</tr>

			</xsl:if>

			<xsl:if test="$node/Page[Value=$pagenumber]/PageInfo/BleedBox/Fixed/Value">

				<tr class="copy">
					<td>Bleed box (pt)</td>
					<td>
						<xsl:value-of
							select="round((number($node/Page[Value=$pagenumber]/PageInfo/BleedBox/Fixed[3]/Value) - number($node/Page[Value=$pagenumber]/PageInfo/BleedBox/Fixed/Value)) )"/>
						<xsl:text>pt / </xsl:text>
						<xsl:value-of
							select="round((number($node/Page[Value=$pagenumber]/PageInfo/BleedBox/Fixed[4]/Value) - number($node/Page[Value=$pagenumber]/PageInfo/BleedBox/Fixed[2]/Value)) )"/>
						<xsl:text>pt (</xsl:text>
						<xsl:text>Shift: </xsl:text>
						<xsl:value-of
							select="round(number($node/Page[Value=$pagenumber]/PageInfo/BleedBox/Fixed/Value) )"/>
						<xsl:text>pt / </xsl:text>
						<xsl:value-of
							select="round(number($node/Page[Value=$pagenumber]/PageInfo/BleedBox/Fixed[2]/Value) )"/>
						<xsl:text>pt)</xsl:text>
					</td>
				</tr>

			</xsl:if>

			<xsl:if test="$node/Page[Value=$pagenumber]/PageInfo/ArtBox/Fixed/Value">

				<tr class="copy">
					<td>Art box (pt)</td>
					<td>
						<xsl:value-of
							select="round((number($node/Page[Value=$pagenumber]/PageInfo/ArtBox/Fixed[3]/Value) - number($node/Page[Value=$pagenumber]/PageInfo/ArtBox/Fixed/Value)) )"/>
						<xsl:text>pt / </xsl:text>
						<xsl:value-of
							select="round((number($node/Page[Value=$pagenumber]/PageInfo/ArtBox/Fixed[4]/Value) - number($node/Page[Value=$pagenumber]/PageInfo/ArtBox/Fixed[2]/Value)) )"/>
						<xsl:text>pt (</xsl:text>
						<xsl:text>Shift: </xsl:text>
						<xsl:value-of
							select="round(number($node/Page[Value=$pagenumber]/PageInfo/ArtBox/Fixed/Value) )"/>
						<xsl:text>pt / </xsl:text>
						<xsl:value-of
							select="round(number($node/Page[Value=$pagenumber]/PageInfo/ArtBox/Fixed[2]/Value) )"/>
						<xsl:text>pt)</xsl:text>
					</td>
				</tr>
			</xsl:if>

			
			<tr class="copy">
				<td>Separations (<xsl:value-of
						select="$node/Page[Value=$pagenumber]/PageInfo/Plates/PlatesNumber/Value"/>)</td>
				<td>
					<xsl:call-template name="GetPlateName">
						<xsl:with-param name="stringIn" select="$node/Page[Value=$pagenumber]/PageInfo/Plates/PlatesName/Value"/>
					</xsl:call-template>
				</td>
			</tr>
		</table>
	</xsl:template>

	<xsl:template name="addSeverityTable">
		<xsl:param name="severity" select="'info'"/>
		<xsl:param name="node" select="/descendant-or-self::RuleInfr"/>
		<xsl:param name="perpage" select="0"/>

		<table width="90%" border="1" cellpadding="3" cellspacing="0">

			<tr class="headline">
				<xsl:if test="$severity='info'">
					<td colspan="3" class="infohead"><xsl:call-template name="InfoIMG"/> INFO (<xsl:value-of select="count($node)"
					/>)</td>
				</xsl:if>
				<xsl:if test="$severity='error'">
					<td colspan="3" class="errhead"><xsl:call-template name="ErrorIMG"/>ERROR (<xsl:value-of select="count($node)"
					/>)</td>
				</xsl:if>
				<xsl:if test="$severity='warning'">
					<td colspan="3" class="warnhead"><xsl:call-template name="WarnIMG"/> WARNING (<xsl:value-of select="count($node)"
					/>)</td>
				</xsl:if>
			</tr>

			<tr class="subline">
				<td width="5" colspan="3">Rule description</td>
			</tr>

			<xsl:for-each select="$node">
				<xsl:sort select="Value"/>

				<xsl:variable name="lastValue" select="Value"/>

				<xsl:if test="$perpage='0'">
					<xsl:if test="not(preceding::RuleInfr[Value=$lastValue])">
						<tr>
							<td class="copy">
								<xsl:value-of select="Value"/> (<xsl:value-of
									select="count($node[Value=$lastValue])"/>) </td>
						</tr>
					</xsl:if>
				</xsl:if>

				<xsl:if test="$perpage='1'">
					<xsl:if test="not(preceding-sibling::RuleInfr[Value=$lastValue])">
						<tr>
							<td class="copy">
								<xsl:value-of select="Value"/> (<xsl:value-of
									select="count($node[Value=$lastValue])"/>) </td>
						</tr>
					</xsl:if>
				</xsl:if>

			</xsl:for-each>

		</table>
	</xsl:template>
	
	<xsl:template name="GetPlateName">
		<xsl:param name="stringIn"/>
		
		<xsl:variable name="first" select="substring-after($stringIn,'(')"/>
		<xsl:variable name="myNewStringa" select="substring($first,0,string-length($first)-2)"/>
		
		<xsl:variable name="myNewStringb">
			<!-- go create the result tree fragment with the replacement -->
			<xsl:call-template name="SubstringReplace">
				<xsl:with-param name="stringIn" select="$myNewStringa"/>
				<xsl:with-param name="substringIn" select="'('"/>
				<xsl:with-param name="substringOut" select="''"/>
			</xsl:call-template>
		</xsl:variable>
		<xsl:variable name="myNewString">
			<!-- go create the result tree fragment with the replacement -->
			<xsl:call-template name="SubstringReplace">
				<xsl:with-param name="stringIn" select="$myNewStringb"/>
				<xsl:with-param name="substringIn" select="')'"/>
				<xsl:with-param name="substringOut" select="','"/>
			</xsl:call-template>
		</xsl:variable>
		
		<xsl:value-of select="$myNewString"/>
		
	</xsl:template>
	
	<xsl:template name="ErrorIMG">
		<img
			src="data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAANbY1E9YMgAAABl0RVh0
			U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAAPUExURfSssOxfU8AfJ98AJP///2Fiq0oA
			AABWSURBVHjaXI9bEsAwCAKJ2/ufuY1oHuVDwTHuRM9PmgV7egBpGXjA58g8m5xRVsIbU5X7hhVN
			0c6FzX20sKPfFHblwvq+uLCxmrF5/8CGP7exp14BBgDH3wNZEIaK+gAAAABJRU5ErkJggg==
			" alt="Error" width="16" height="16" />
	</xsl:template>
	
	<xsl:template name="WarnIMG">
		<img
			src="data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAANbY1E9YMgAAABl0RVh0
			U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAAVUExURf785f77iO+cAPbFA/fnBQAAAP//
			/3eozhwAAABbSURBVHjadI9BCsBACAOjif3/k7tmpWULzUUcMoK4PsFM6gRKnoAP2YABpl4gomoq
			2IWoGgk+EFqAJmgh1GBVZNC7gSVYmLQEC9NoCRQ7VR5J5Bni79sntwADAJULBJwmJOTFAAAAAElF
			TkSuQmCC
			" alt="Warning" width="16" height="16" />
	</xsl:template>
	
	<xsl:template name="InfoIMG">
		<img
			src="data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAANbY1E9YMgAAABl0RVh0
			U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAASUExURQdqs6bY9m265SRVpgCR1f///8zj
			BTAAAABgSURBVHjaXI9REgAhCEJR7P5XXtGtnPhw8hmMYj1CVfOUXeAeEjZQm7+aoHovH4MC5uEH
			WAL1ZWF62ECBZBygeYVekI9r0SR+UKELbRFiL4ZMbO3VSUB0HKfxOG7qE2AACNgDy2qK04YAAAAA
			SUVORK5CYII=
			" alt="Info" width="16" height="16" />
	</xsl:template>
	
	<xsl:template name="OKIMG">
		<img
			src="data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAANbY1E9YMgAAABl0RVh0
			U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAAtUExURV2NOHi5TrXjzJPKY7ryelytQ+Lv
			5tHgy7OzskhqHv75/HLBiQScNgN0Nv///+08dwAAAABfSURBVHjaXM5ZAoAgCATQKbUNhvsfN5dS
			lL83iADzJWaYTJmCbAq8gyqxeLzYuRX3P5r3suWoY9Wlg5tgMEmfDVRRRvzOI9SM7hyc1DRctlyu
			X4MHHG53MC6Br1eAAQC0VAyjnnhF9QAAAABJRU5ErkJggg==
			" alt="OK" width="16" height="16" />
	</xsl:template>
	
	<xsl:template name="PDFIMG">
		<img
			src="data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAMAAAAoLQ9TAAAABGdBTUEAANbY1E9YMgAAABl0RVh0
			U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAABdUExURf8wOdYAAM5ZWv9xc4yOjP9hY/+u
			rSkoKf8gKf8QEL2+xueOjO/f3u/v9722vVpZWu+enKWmpe+2tda2te/3//dJSvcAADEwMcbHzowI
			CBAQEHtxe97X3u/v7////+DWxbMAAACTSURBVHjaTM3ZFoMgDATQoOCuXWnQJvP/n2nQ0nZe4NzA
			hAC8S+wOypCGYVhuXjhDHWKMRNQ5D3AG6vqXxa35B4NC12dwbvXW4pncWqIpLWk7SiWJVKJi5wl2
			RVRVSVpAJ7rCpICinscGfzDFpomxGnECUN2nJ+ZHKC9spEfpZ0uoc6H81uKcf+HCzC237ZazCzAA
			yVsW+WGRPIUAAAAASUVORK5CYII=
			" alt="PDF File" width="16" height="16" />
	</xsl:template>
	
	
	<xsl:template name="SubstringReplace">
		<xsl:param name="stringIn"/>
		<xsl:param name="substringIn"/>
		<xsl:param name="substringOut"/>
		<xsl:choose>
			<xsl:when test="contains($stringIn,$substringIn)">
				<xsl:value-of select="concat(substring-before($stringIn,$substringIn),$substringOut)"/>
				<xsl:call-template name="SubstringReplace">
					<xsl:with-param name="stringIn" select="substring-after($stringIn,$substringIn)"/>
					<xsl:with-param name="substringIn" select="$substringIn"/>
					<xsl:with-param name="substringOut" select="$substringOut"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$stringIn"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
</xsl:stylesheet>

