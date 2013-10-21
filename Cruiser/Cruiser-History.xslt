<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:t="http://schemas.microsoft.com/powershell/2004/04" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl">
	<xsl:output method="html" indent="yes"/>

	<xsl:template match="/">

		<html>
			<head>
				<title>Cruiser History</title>
				<style type="text/css">
					body {
						font-family: Calibri, Arial;
						font-size: 16px;
						padding: 0;
						margin: 0;
					}
					
					a {
						color: #16408A;
					}
					
					#header {
						font-size: 35px;
						background-color: #16408A;
						padding: 3px 10px 5px 10px;
						color: white;
						height: 40px;
					}
					
					#body, #header-inner {
						width: 970px;
						margin: 0 auto;
					}
					
					table#project-list {
						width: 100%;
						margin-top: 25px;
					}
					
					table#project-list tr:nth-child(even) { 
						background-color: #eee; 
					}

					table#project-list tr.header td {
						border-bottom: 1px solid black;
					}

					table#project-list tr td.version {
					}

					table#project-list tr td.output {
						width: 80px;
					}

					table#project-list tr td.state {
						width: 80px;
					}

					table#project-list tr td.name {
						width: 200px;
					}

					table#project-list td {
						padding: 3px 5px;
					}

					tr.build {
						display: none;
					}
					
					tr.spacer td {
						padding: 3px 0;
					}
					
					div#poll, div#poll {
						margin-bottom: 5px;
					}
					
					div#poll, div#poll td {
						float: right;
						color: white;
						font-size: 14px;
						text-align: right;
					}
					
				</style>
			</head>
			<body>

				<xsl:variable name="projects" select="/t:Objs/t:Obj/t:DCT/t:En/t:Obj[@N='Value']/t:DCT/t:En/t:S[@N='Key' and text()='builds']/../../../.." />
				<xsl:variable name="last_poll" select="/t:Objs/t:Obj/t:DCT/t:En/t:S[@N='Key' and text()='last_poll_start_str']/following-sibling::t:S[@N='Value']" />
				<xsl:variable name="next_poll" select="/t:Objs/t:Obj/t:DCT/t:En/t:S[@N='Key' and text()='next_poll_start_str']/following-sibling::t:S[@N='Value']" />

				<div id="header">
					<div id="header-inner">
						Cruiser History
						
						<div id="poll">
							<table>
								<tr>
									<td>Last Poll:</td>
									<td>
										<xsl:value-of select="$last_poll" />
									</td>
								</tr>
								<xsl:if test="$next_poll != ''">
									<tr>
										<td>Next Poll:</td>
										<td>
											<xsl:value-of select="$next_poll" />
										</td>
									</tr>
								</xsl:if>
							</table>
						</div>
					
					</div>
				</div>

				<div id="body">
					

					<table id="project-list">
						<tr class="header">
							<td class="name">Project</td>
							<td class="version"></td>
							<td class="output"></td>
							<td class="state">State</td>
							<td class="date">Start</td>
							<td class="date">End</td>
						</tr>
						
						<xsl:for-each select="$projects">
							<xsl:sort select="current()/t:S[@N='Key']" data-type="text" order="ascending"/>
							<xsl:variable name="project_name" select="current()/t:S[@N='Key']" />
							<xsl:variable name="builds" select="current()/t:Obj[@N='Value']/t:DCT/t:En/t:S[@N='Key' and text()='builds']/following-sibling::t:Obj[@N='Value']/t:LST/t:Obj" />
							<xsl:variable name="project_build_state" select="$builds[position()=last()]/t:DCT/t:En/t:S[@N='Key' and text()='state']/following-sibling::t:S[@N='Value']" />
							<xsl:variable name="project_build_version" select="$builds[position()=last()]/t:DCT/t:En/t:S[@N='Key' and text()='version']/following-sibling::t:S[@N='Value']" />
							<xsl:variable name="project_build_start" select="$builds[position()=last()]/t:DCT/t:En/t:S[@N='Key' and text()='start_str']/following-sibling::t:S[@N='Value']" />
							<xsl:variable name="project_build_end" select="$builds[position()=last()]/t:DCT/t:En/t:S[@N='Key' and text()='end_str']/following-sibling::t:S[@N='Value']" />

							<xsl:variable name="project_log_path" select="$builds[position()=last()]/t:DCT/t:En/t:S[@N='Key' and text()='log_path']/following-sibling::t:S[@N='Value']" />
							<xsl:variable name="project_output_dir" select="$builds[position()=last()]/t:DCT/t:En/t:S[@N='Key' and text()='output_dir']/following-sibling::t:S[@N='Value']" />

							<tr class="project">
								<td class="name">
									<xsl:value-of select="$project_name" />
									(<xsl:value-of select="count($builds)" />)
								</td>
								<td class="version">
									<xsl:if test="$project_log_path != ''">
										<a href="{$project_log_path}"><xsl:value-of select="$project_build_version" /></a>
									</xsl:if>
								</td>
								<td class="output">
									<xsl:if test="$project_output_dir != ''">
										<a href="{$project_output_dir}">output</a>
									</xsl:if>
								</td>
								<td class="state">
									<xsl:if test="$project_build_state != ''">
										<xsl:value-of select="$project_build_state" />
									</xsl:if>
								</td>

								<td class="date">
									<xsl:if test="$project_build_start != ''">
										<xsl:value-of select="$project_build_start" />
									</xsl:if>
								</td>
								<td class="date">
									<xsl:if test="$project_build_end != ''">
										<xsl:value-of select="$project_build_end" />
									</xsl:if>
								</td>
							</tr>
							<xsl:for-each select="$builds">
								<xsl:sort select="position()" data-type="number" order="descending"/>
								<xsl:variable name="version" select="current()/t:DCT/t:En/t:S[@N='Key' and text()='version']/following-sibling::t:S[@N='Value']" />
								<xsl:variable name="start" select="current()/t:DCT/t:En/t:S[@N='Key' and text()='start_str']/following-sibling::t:S[@N='Value']" />
								<xsl:variable name="end" select="current()/t:DCT/t:En/t:S[@N='Key' and text()='end_str']/following-sibling::t:S[@N='Value']" />
								<xsl:variable name="state" select="current()/t:DCT/t:En/t:S[@N='Key' and text()='state']/following-sibling::t:S[@N='Value']" />
								<xsl:variable name="log_path" select="current()/t:DCT/t:En/t:S[@N='Key' and text()='log_path']/following-sibling::t:S[@N='Value']" />
								<xsl:variable name="output_dir" select="current()/t:DCT/t:En/t:S[@N='Key' and text()='output_dir']/following-sibling::t:S[@N='Value']" />
								<tr class="build">
									<td class="name">
									</td>
									<td class="version">
										<a href="{$log_path}"><xsl:value-of select="$version" /></a>
									</td>
									<td class="output">
										<a href="{$output_dir}">output</a>
									</td>
									<td class="state">
										<xsl:value-of select="$state" />
									</td>
									<td class="date">
										<xsl:value-of select="$start" />
									</td>
									<td class="date">
										<xsl:value-of select="$end" />
									</td>
								</tr>
							</xsl:for-each>
						</xsl:for-each>
					</table>
				</div>

			</body>
		</html>
	</xsl:template>

	<!--<xsl:template match="@* | node()">
        <xsl:copy>
            <xsl:apply-templates select="@* | node()"/>
        </xsl:copy>
    </xsl:template>-->
</xsl:stylesheet>
