<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output encoding="UTF-8"
                indent="yes"
                method="xml" />

    <!--
        Variables filled by ANT call
    -->
    <xsl:param name="project.default-target" />
    <xsl:param name="project.build.file" />
    <xsl:param name="project.name" />
    <xsl:param name="project.directory" />
    <xsl:param name="project.build.directory" />

    <xsl:param name="abc.extensions.directory" />
    <xsl:param name="project.extensions.directory" />

    <xsl:param name="abc.mode" />

    <!--
        Basic Document Transformations
    -->
    <xsl:template match="/">
        <project name="{$project.name}#generated"
                 basedir="{$project.directory}"
                 default="{$project.default-target}">

            <!--
                Let the system know, that we are in runtime mode now
            -->
            <property name="abc.runtime.mode" value="true" />

            <!--
                Exposed default properties based on the original build file
                !! Can not be overwritten by the user. as they depend on the configure process !!
            -->
            <property name="project.directory" value="{$project.directory}" />
            <property name="project.build.directory" value="{$project.build.directory}" />

            <!-- Import the original build file first, to allow it overwriting abc related properties -->
            <import file="{$project.build.file}" />

            <!--
                Exposed default properties based on the original build file
                !! May be overwritten by user configuration !!
            -->
            <property name="project.name" value="{$project.name}" />

            <xsl:apply-templates select="/abc/project" />

            <!--
                Overwrite configure target, to reconfigure the build system automatically
            -->
            <xsl:choose>
                <xsl:when test="$abc.mode = 'runtime'">
                    <target name="configure">
                        <java classname="org.apache.tools.ant.Main"
                              classpath="${{java.class.path}}"
                              taskname="configure"
                              fork="true"
                              dir="{$project.build.directory}">
                            <arg value="-emacs" />
                            <arg value="-buildfile" />
                            <arg value="{$project.build.file}" />
                            <arg value="configure" />
                        </java>
                    </target>
                </xsl:when>
                <xsl:otherwise>
                    <target name="configure"
                            depends="-configure:before~hook,
                                     -configure:main~hook,
                                     -configure:after~hook" />
                </xsl:otherwise>
            </xsl:choose>
        </project>
    </xsl:template>

    <xsl:template match="/abc/project">
        <xsl:variable name="project.name" select="@name" />

        <xsl:variable name="project.namespace">
            <xsl:call-template name="string.get.parent">
                <xsl:with-param name="input" select="$project.name" />
                <xsl:with-param name="delimiter" select="':'" />
            </xsl:call-template>
        </xsl:variable>

        <xsl:variable name="profile.enabled">
            <xsl:choose>
                <xsl:when test="/abc/profile-defaults/profile[text() = $project.namespace and @default='disabled']">
                    <xsl:text>false</xsl:text>
                </xsl:when>
                <xsl:when test="/abc/profile-defaults/profile[text() = $project.namespace and @default='enabled']">
                    <xsl:text>true</xsl:text>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:call-template name="profile.enabled">
                        <xsl:with-param name="profile.name">
                            <xsl:call-template name="profile.from.project.namespace">
                                <xsl:with-param name="project.namespace"
                                                select="$project.namespace" />
                            </xsl:call-template>
                        </xsl:with-param>
                    </xsl:call-template>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:if test="$profile.enabled = 'true'">
            <xsl:element name="import">
                <xsl:attribute name="file">
                    <xsl:call-template name="file.from.project.name">
                        <xsl:with-param name="project.name" select="$project.name" />
                    </xsl:call-template>
                </xsl:attribute>
            </xsl:element>
        </xsl:if>
    </xsl:template>

    <!--
        Utillity Functions
    -->
    <xsl:template name="profile.from.project.namespace">
        <xsl:param name="project.namespace" />

        <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz'" />
        <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'" />

        <xsl:value-of select="concat(
                'profile.',
                translate(
                    translate(
                        $project.namespace,
                        $uppercase,
                        $lowercase
                    ),
                    ':',
                    '.'
                )
            )" />
    </xsl:template>

    <xsl:template name="file.from.project.name">
        <xsl:param name="project.name" />

        <xsl:variable name="extensions.directory">
            <xsl:choose>
                <xsl:when test="starts-with($project.name, 'ABC:')">
                    <xsl:value-of select="$abc.extensions.directory" />
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$project.extensions.directory" />
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>

        <xsl:value-of select="concat(
                $extensions.directory,
                '/',
                translate($project.name, ':', '/'),
                '.xml'
            )" />
    </xsl:template>

    <xsl:template name="profile.enabled">
        <xsl:param name="profile.name" />

        <xsl:choose>
            <xsl:when test="/abc/properties/property[@name = $profile.name]">
                <xsl:choose>
                    <xsl:when test="/abc/properties/property[@name = $profile.name][@value = 'enabled']">
                        <xsl:text>true</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text>false</xsl:text>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:when test="$profile.name != 'profile'">
                <xsl:call-template name="profile.enabled">
                    <xsl:with-param name="profile.name">
                        <xsl:call-template name="string.get.parent">
                            <xsl:with-param name="input"
                                            select="$profile.name" />
                        </xsl:call-template>
                    </xsl:with-param>
                </xsl:call-template>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="string.get.parent">
        <xsl:param name="input" />
        <xsl:param name="delimiter" select="'.'" />

        <xsl:if test="contains($input, $delimiter)">
            <xsl:value-of select="substring-before($input, $delimiter)" />
            <xsl:if test="contains(substring-after($input, $delimiter), $delimiter)">
                <xsl:value-of select="$delimiter" />
            </xsl:if>
            <xsl:call-template name="string.get.parent">
                <xsl:with-param name="input"
                                select="substring-after($input, $delimiter)" />
                <xsl:with-param name="delimiter" select="$delimiter" />
            </xsl:call-template>
        </xsl:if>
    </xsl:template>

</xsl:stylesheet>