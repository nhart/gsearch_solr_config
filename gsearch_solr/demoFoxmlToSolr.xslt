<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xalan="http://xml.apache.org/xalan"
    xmlns:exts="xalan://dk.defxws.fedoragsearch.server.GenericOperationsImpl"
    xmlns:zs="http://www.loc.gov/zing/srw/"
    xmlns:foxml="info:fedora/fedora-system:def/foxml#"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:mods="http://www.loc.gov/mods/v3"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:fedora="info:fedora/fedora-system:def/relations-external#"
    xmlns:rel="info:fedora/fedora-system:def/relations-external#"
    xmlns:fractions="http://vre.upei.ca/fractions/"
    xmlns:compounds="http://vre.upei.ca/compounds/"
    xmlns:critters="http://vre.upei.ca/critters/"
    xmlns:dwc="http://rs.tdwg.org/dwc/xsd/simpledarwincore/"
    xmlns:fedora-model="info:fedora/fedora-system:def/model#"
    xmlns:uvalibdesc="http://dl.lib.virginia.edu/bin/dtd/descmeta/descmeta.dtd"
    xmlns:pb="http://www.pbcore.org/PBCore/PBCoreNamespace.html"
    xmlns:uvalibadmin="http://dl.lib.virginia.edu/bin/admin/admin.dtd/"
    xmlns:eaccpf="urn:isbn:1-931666-33-4"
    xmlns:sparql="http://www.w3.org/2001/sw/DataAccess/rf1/result"
    xmlns:encoder="xalan://java.net.URLEncoder"
    exclude-result-prefixes="exts zs foxml dc oai_dc tei mods rdf rdfs fedora rel fractions compounds critters dwc fedora-model uvalibdesc pb uvalibadmin eaccpf xalan sparql encoder">
    <xsl:import href="file:///fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/config/index/gsearch_solr/islandora_transforms/xslt-date-template.xslt"/>
    <xsl:import href="file:///fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/config/index/gsearch_solr/islandora_transforms/traverse-graph.xslt"/>
    <xsl:include href="file:///fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/config/index/gsearch_solr/islandora_transforms/FOXML_properties_to_solr.xslt"/>
    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

    <!--
	 This xslt stylesheet generates the Solr doc element consisting of field elements
     from a FOXML record. The PID field is mandatory.
     Options for tailoring:
       - generation of fields from other XML metadata streams than DC
       - generation of fields from other datastream types than XML
         - from datastream by ID, text fetched, if mimetype can be handled
             currently the mimetypes text/plain, text/xml, text/html, application/pdf can be handled.
-->

    <xsl:param name="REPOSITORYNAME" select="repositoryName"/>
    <xsl:param name="FEDORASOAP" select="repositoryName"/>
    <xsl:param name="FEDORAUSER" select="repositoryName"/>
    <xsl:param name="FEDORAPASS" select="repositoryName"/>
    <xsl:param name="TRUSTSTOREPATH" select="repositoryName"/>
    <xsl:param name="TRUSTSTOREPASS" select="repositoryName"/>

    <xsl:variable name="FEDORA" xmlns:java_string="xalan://java.lang.String" select="substring($FEDORASOAP, 1, java_string:lastIndexOf(java_string:new(string($FEDORASOAP)), '/'))"/>

    <xsl:variable name="docBoost" select="1.4*2.5"/>
    <!-- or any other calculation, default boost is 1.0 -->

    <!-- NOTE: The structure of wrapping everything in <update> seems to break the manner in which GSearch counts additions/deletions/etc. -->
    <xsl:template match="/foxml:digitalObject">
      <update>
        <xsl:choose>
          <!-- The following allows only active FedoraObjects to be indexed. -->
          <xsl:when test="foxml:objectProperties/foxml:property[@NAME='info:fedora/fedora-system:def/model#state' and @VALUE='Active'] and not(foxml:datastream[@ID='METHODMAP'] or foxml:datastream[@ID='DS-COMPOSITE-MODEL']) and @PID">
            <add commitWithin="5000"><!-- Since 1.4, you can specify the amount of time to allow to elapse before causing a commit. In 3, it seems that the usage of 'autoCommits' (as set in the solrConfig.xml) has been disabled by default in favour of this option. -->
              <doc>
                <xsl:attribute name="boost">
                    <xsl:value-of select="$docBoost"/>
                </xsl:attribute>
                <xsl:apply-templates select="current()" mode="activeFedoraObject"/>
              </doc>
            </add>
          </xsl:when>
          <xsl:otherwise>
            <delete>
              <id><xsl:value-of select="@PID"/></id>
            </delete>
          </xsl:otherwise>
        </xsl:choose>

        <xsl:variable name="graph">
	  <xsl:call-template name="_traverse_graph">
            <xsl:with-param name="risearch" select="concat($FEDORA, '/risearch')"/>
	    <xsl:with-param name="to_traverse_in">
	      <sparql:result>
		<sparql:obj>
		  <xsl:attribute name="uri">info:fedora/<xsl:value-of select="@PID"/></xsl:attribute>
		</sparql:obj>
	      </sparql:result>
	    </xsl:with-param>
	    <xsl:with-param name="query">
PREFIX fre: &lt;info:fedora/fedora-system:def/relations-external#&gt;
PREFIX fm: &lt;info:fedora/fedora-system:def/model#&gt;
SELECT ?obj
FROM &lt;#ri&gt;
WHERE {
  {
    ?sub fm:hasModel &lt;info:fedora/usc:collectionCModel&gt; {
      ?vro fre:isMemberOfCollection ?sub .
      ?mezz fre:isDerivativeOf ?vro .
      ?obj fre:isDerivativeOf ?mezz
    }
    UNION {
      ?vro fre:isMemberOfCollection ?sub .
      ?obj fre:isDerivativeOf ?vro
    }
    UNION {
      ?obj fre:isMemberOfCollection ?sub
    }
  }
  UNION{
    ?sub fm:hasModel &lt;info:fedora/usc:vroCModel&gt; .
    ?obj fre:isDerivativeOf ?sub .
  }
  ?obj fm:state fm:Active
  FILTER(sameTerm(?sub, &lt;%PID_URI%&gt;))
}
	    </xsl:with-param>
	  </xsl:call-template>
        </xsl:variable>
        <add commitWithin="5000">
	  <xsl:for-each select="xalan:nodeset($graph)//sparql:obj">
	    <xsl:variable name="xml_url" select="concat(substring-before($FEDORA, '://'), '://', encoder:encode($FEDORAUSER), ':', encoder:encode($FEDORAPASS), '@', substring-after($FEDORA, '://') , '/objects/', substring-after(@uri, '/'), '/objectXML')"/>
            <!-- XXX: This requires a custom URIResolver...  The default doesn't handle HTTP basic auth... -->
            <xsl:variable name="object" select="document($xml_url)"/>
            <xsl:if test="$object">
	      <doc>
		<xsl:attribute name="boost">
		    <xsl:value-of select="$docBoost"/>
		</xsl:attribute>
		<xsl:apply-templates select="$object/foxml:digitalObject" mode="activeFedoraObject"/>
	      </doc>
            </xsl:if>
	  </xsl:for-each>
        </add>
      </update>
    </xsl:template>

    <xsl:template match="foxml:datastream[@STATE='A']">
      <xsl:param name="pid"/>
      <xsl:param name="mimetype" select="foxml:datastreamVersion[last()]/@MIMETYPE"/>

      <field name="fedora_active_datastream_state">
        <xsl:value-of select="@ID"/>
      </field>

      <!-- do different stuff, based on mimetype -->
      <xsl:choose>
        <!-- XML -->
        <xsl:when test="$mimetype='text/xml' or $mimetype='application/rdf+xml' or $mimetype='application/xml'">
          <xsl:choose>
            <xsl:when test="@CONTROL_GROUP='X'"><!-- XML, but not inline -->
              <xsl:apply-templates select="foxml:datastreamVersion[last()]/foxml:xmlContent">
                <xsl:with-param name="pid" select="$pid"/>
              </xsl:apply-templates>
            </xsl:when>
            <xsl:otherwise>
              <xsl:variable name="ds_url" select="concat(substring-before($FEDORA, '://'), '://', encoder:encode($FEDORAUSER), ':', encoder:encode($FEDORAPASS), '@', substring-after($FEDORA, '://') , '/objects/', $pid, '/datastreams/', @ID,'/content')"/>
              <xsl:apply-templates select="document($ds_url)">
                <xsl:with-param name="pid" select="$pid"/>
              </xsl:apply-templates>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test="$mimetype='text/plain'">
          <xsl:call-template name="plaintext">
            <xsl:with-param name="text" select="exts:getDatastreamText($pid, $REPOSITORYNAME, @ID, $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
            <xsl:with-param name="dsid" select="@ID"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <!-- TODO: something logical -->
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <xsl:template match="foxml:datastream[@STATE='I']">
      <xsl:param name="pid"/>
      <xsl:param name="mimetype" select="foxml:datastreamVersion[last()]/@MIMETYPE"/>

      <field name="fedora_inactive_datastream_state">
        <xsl:value-of select="@ID"/>
      </field>
    </xsl:template>

    <xsl:template match="foxml:datastream[@STATE='D']">
      <xsl:param name="pid"/>
      <xsl:param name="mimetype" select="foxml:datastreamVersion[last()]/@MIMETYPE"/>

      <field name="fedora_deleted_datastream_state">
        <xsl:value-of select="@ID"/>
      </field>
    </xsl:template>

    <xsl:template match="oai_dc:dc">
      <xsl:param name="prefix">dc_</xsl:param>
      <xsl:param name="suffix"></xsl:param>

      <xsl:for-each select="./*">
        <xsl:variable name="text" select="normalize-space(text())"/>
        <xsl:if test="$text">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$text"/>
          </field>
        </xsl:if>
      </xsl:for-each>
    </xsl:template>

    <xsl:template match="foxml:digitalObject" mode="activeFedoraObject">
      <field name="PID">
          <xsl:value-of select="@PID"/>
      </field>

      <!-- allow every datastream a chance to get indexed. -->
      <xsl:apply-templates select="foxml:datastream">
        <xsl:with-param name="pid" select="@PID"/>
      </xsl:apply-templates>

      <xsl:apply-templates select="foxml:objectProperties"/> 
      <!-- index info from the collection -->
      <xsl:call-template name="index_collection">
        <xsl:with-param name="full_pid" select="concat('info:fedora/', @PID)"/>
      </xsl:call-template>
    </xsl:template>

    <xsl:template name="index_collection">
      <xsl:param name="full_pid"/>

      <!-- perform a query to find the collection object -->
      <xsl:variable name="results">
        <xsl:call-template name="perform_query">
          <xsl:with-param name="query">
PREFIX fre: &lt;info:fedora/fedora-system:def/relations-external#&gt;
PREFIX fm: &lt;info:fedora/fedora-system:def/model#&gt;
SELECT ?collection
WHERE {{
    &lt;<xsl:value-of select="$full_pid"/>&gt; fm:hasModel &lt;info:fedora/usc:vroCModel&gt; ;
                                               fre:isMemberOfCollection ?collection .
  }
  UNION {
    &lt;<xsl:value-of select="$full_pid"/>&gt; fm:hasModel &lt;info:fedora/usc:mezzanineCModel&gt; ;
                                               fre:isDerivativeOf ?vro .
    ?vro fre:isMemberOfCollection ?collection .
  }
  UNION {
    <!-- XXX: The model URI is in the wrong namespace for access copies. -->
    &lt;<xsl:value-of select="$full_pid"/>&gt; fre:hasModel &lt;info:fedora/usc:accessCModel&gt; ;
                                               fre:isDerivativeOf ?mezz .
    ?mezz fre:isDerivativeOf ?vro1 .
    ?vro1 fre:isMemberOfCollection ?collection .
  }
}
          </xsl:with-param>
          <xsl:with-param name="lang">sparql</xsl:with-param>
        </xsl:call-template>
      </xsl:variable>

      <xsl:for-each select="xalan:nodeset($results)/sparql:sparql/sparql:results/sparql:result/sparql:collection">
	<!-- get the MODS from the collection object... -->
	<!-- ... and apply-templates on it -->
        <field name="usc_parent_collection_pid_ms">
          <xsl:value-of select="substring-after(@uri, '/')"/>
        </field>
        <xsl:variable name="mods_url" select="concat(substring-before($FEDORA, '://'), '://', encoder:encode($FEDORAUSER), ':', encoder:encode($FEDORAPASS), '@', substring-after($FEDORA, '://') , '/objects/', substring-after(@uri, '/'), '/datastreams/MODS/content')"/>
        <xsl:apply-templates select="document($mods_url)/mods:mods">
          <xsl:with-param name="pid" select="substring-after(@uri, '/')"/>
          <xsl:with-param name="prefix">collection_mods_</xsl:with-param>
        </xsl:apply-templates>
      </xsl:for-each>
    </xsl:template>

    <xsl:template name="plaintext">
      <xsl:param name="prefix">plaintext_</xsl:param>
      <xsl:param name="suffix">_ms</xsl:param>
      <xsl:param name="text"/>
      <xsl:param name="dsid">OBJ</xsl:param>

      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, $dsid, $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="$text"/>
      </field>
    </xsl:template>


    <!-- **** General RDF indexing **** -->
    <!-- add RDF URI -->
    <xsl:template match="*[@rdf:resource]" mode="rdf">
      <xsl:param name="prefix">rels_</xsl:param>
      <xsl:param name="suffix"></xsl:param>

      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_uri', $suffix)"/>
        </xsl:attribute>

        <xsl:variable name="subbed" select="substring-after(@rdf:resource, 'info:fedora/')"/>
        <xsl:choose>
          <!-- account for relationships to arbitrary URIs -->
          <xsl:when test="$subbed">
            <xsl:value-of select="substring-after(@rdf:resource, 'info:fedora/')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="@rdf:resource"/>
          </xsl:otherwise>
        </xsl:choose>
      </field>
    </xsl:template>

    <!-- add RDF literal -->
    <xsl:template match="*[normalize-space(text())]" mode="rdf">
      <xsl:param name="prefix">rels_</xsl:param>
      <xsl:param name="suffix"></xsl:param>

      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_literal', $suffix)"/>
        </xsl:attribute>

        <xsl:value-of select="normalize-space(text())"/>
      </field>
    </xsl:template>

    <!-- kick off RDF indexing -->
    <xsl:template match="rdf:Description | rdf:description" mode="rdf">
      <xsl:param name="prefix">rels_</xsl:param>
      <xsl:param name="suffix"></xsl:param>

      <xsl:variable name="pid_dsid" select="substring-after(@rdf:about, '/')"/>
      <xsl:variable name="dsid" select="substring-after($pid_dsid, '/')"/>

      <xsl:choose>
        <!-- probably adding in the dsid, since there's something after info:fedora/$PID -->
        <xsl:when test="$dsid">
          <xsl:apply-templates mode="rdf">
            <xsl:with-param name="prefix" select="concat($prefix, $dsid, '_')"/>
            <xsl:with-param name="suffix" select="$suffix"/>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates mode="rdf">
            <xsl:with-param name="prefix" select="$prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>

    <!-- index children... -->
    <xsl:template match="*" mode="rdf">
      <xsl:param name="prefix">rels_</xsl:param>
      <xsl:param name="suffix">_ms</xsl:param>

      <xsl:apply-templates mode="rdf">
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
      </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="text()" mode="rdf"/>

    <xsl:template match="rdf:RDF">
      <xsl:param name="prefix">rels_</xsl:param>
      <xsl:param name="suffix">_ms</xsl:param>

      <xsl:apply-templates mode="rdf">
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
      </xsl:apply-templates>
    </xsl:template>
    <!-- **** END RDF **** -->

    <!-- Basic EAC-CPF -->
    <xsl:template match="eaccpf:eac-cpf">
      <xsl:param name="pid"/>
      <xsl:param name="dsid" select="'EAC-CPF'"/>
      <xsl:param name="prefix" select="'eaccpf_'"/>
      <xsl:param name="suffix" select="'_et'"/> <!-- 'edged' (edge n-gram) text, for auto-completion -->

      <xsl:variable name="cpfDesc" select="eaccpf:cpfDescription"/>
      <xsl:variable name="identity" select="$cpfDesc/eaccpf:identity"/>
      <xsl:variable name="name_prefix" select="concat($prefix, 'name_')"/>
      <!-- ensure that the primary is first -->
      <xsl:apply-templates select="$identity/eaccpf:nameEntry[@localType='primary']">
        <xsl:with-param name="prefix" select="$name_prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
      </xsl:apply-templates>

      <!-- place alternates (non-primaries) later -->
      <xsl:apply-templates select="$identity/eaccpf:nameEntry[not(@localType='primary')]">
        <xsl:with-param name="prefix" select="$name_prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
      </xsl:apply-templates>
    </xsl:template>

    <xsl:template match="eaccpf:nameEntry">
      <xsl:param name="prefix">eaccpf_name_</xsl:param>
      <xsl:param name="suffix">_et</xsl:param>

      <!-- fore/first name -->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'given', $suffix)"/>
        </xsl:attribute>
        <xsl:choose>
          <xsl:when test="part[@localType='middle']">
            <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='forename'], ' ', eaccpf:part[@localType='middle']))"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space(eaccpf:part[@localType='forename'])"/>
          </xsl:otherwise>
        </xsl:choose>
      </field>

      <!-- sur/last name -->
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'family', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="normalize-space(eaccpf:part[@localType='surname'])"/>
      </field>

      <!-- id -->
      <!--
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'id', $suffix)"/>
        </xsl:attribute>
        <xsl:choose>
          <xsl:when test="@id">
            <xsl:value-of select="concat($PID, '/', @id)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="concat($PID,'/name_position:', position())"/>
          </xsl:otherwise>
        </xsl:choose>
      </field>
      -->

      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'complete', $suffix)"/>
        </xsl:attribute>
        <xsl:choose>
          <xsl:when test="normalize-space(part[@localType='middle'])">
            <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='surname'], ', ', eaccpf:part[@localType='forename'], ' ', eaccpf:part[@localType='middle']))"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space(concat(eaccpf:part[@localType='surname'], ', ', eaccpf:part[@localType='forename']))"/>
          </xsl:otherwise>
        </xsl:choose>
      </field>
    </xsl:template>

    <!--
    General MODS indexing...
    FIXME: For optimization, it would be best to get rid of all the global (//) selectors. -->
    <xsl:template match="mods:mods">
      <xsl:param name="pid"/>
      <xsl:param name="prefix">mods_</xsl:param>  <!-- Prefix for field names -->
      <xsl:param name="single_suffix">_s</xsl:param>  <!-- Suffix for fields with a single value -->
      <xsl:param name="suffix">_ms</xsl:param>       <!-- Suffix for multivalued fields -->

      <xsl:for-each select=".//mods:title[normalize-space(text())]">
        <field>
          <xsl:attribute name="name">
            <xsl:choose>
              <xsl:when test="position()=1">
                <xsl:value-of select="concat($prefix, local-name(), $single_suffix)"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(concat(../mods:nonSort/text(), ' ', text()))"/>
        </field>
      </xsl:for-each>

      <xsl:for-each select=".//mods:originInfo/mods:dateIssued | .//mods:originInfo/mods:dateCreated">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>

          <xsl:if test="@point">
	    <xsl:variable name="dateValue">
	      <xsl:call-template name="get_ISO8601_date">
		<xsl:with-param name="date" select="$textValue"/>
	      </xsl:call-template>
	    </xsl:variable>
	    <xsl:if test="$dateValue">
	      <field>
		<xsl:attribute name="name">
		  <xsl:value-of select="concat($prefix, local-name(), '_mdt')"/>
                </xsl:attribute>
		<xsl:value-of select="$dateValue"/>
	      </field>
	    </xsl:if>
          </xsl:if>
        </xsl:if>
      </xsl:for-each>

      <!-- Many elements get transformed in the same manner... -->
      <xsl:for-each select=".//mods:subTitle | .//mods:abstract | .//mods:genre | .//mods:form | .//mods:note[not(@type='statement of responsibility')] | .//mods:topic | .//mods:geographic | .//mods:caption | .//mods:extent | .//mods:accessCondition | .//mods:country | .//mods:county | .//mods:province | .//mods:region | .//mods:city | .//mods:citySection | .//mods:originInfo/mods:issuance | .//mods:physicalLocation | .//mods:identifier | .//mods:originInfo/mods:edition | .//mods:originInfo/mods:publisher">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <!-- get all the names... -->
      <xsl:for-each select=".//mods:name">
        <xsl:variable name="authority_uri" select="@valueURI"/>
        <xsl:variable name="role" select="normalize-space(mods:role/mods:roleTerm/text())"/>
        <xsl:variable name="name" select="normalize-space(mods:namePart/text())"/>

        <!-- They'll only get used if they have a role and namePart value, though -->
        <xsl:choose>
          <xsl:when test="$role and $authority_uri">
            <xsl:variable name="authority_type" select="substring-before($authority_uri, '/')"/>
            <xsl:variable name="remaining" select="substring-after($authority_uri, '/')"/>

            <xsl:choose>
              <xsl:when test="$authority_type='info:fedora'">
                <xsl:variable name="pid" select="substring-before($remaining, '/')"/>
                <xsl:variable name="full_fragment" select="substring-after($remaining, '/')"/>
                <xsl:variable name="dsid">
                  <xsl:choose>
                    <xsl:when test="substring-before($full_fragment, '#')">
                      <xsl:value-of select="substring-before($full_fragment, '#')"/>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="$full_fragment"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:variable>
                <xsl:variable name="xml_id" select="substring-after($full_fragment, '#')"/>

                <!-- TODO:  Load the DS and build the name entry... -->
                <xsl:variable name="extracted_name">
                  <!--<xsl:choose>
                    <xsl:when test="$dsid='EAC-CPF'">
                      <xsl:for-each select="">
                    </xsl:when>
                    <xsl:otherwise>
                    </xsl:otherwise>
                  </xsl:choose>-->
                </xsl:variable>

                <xsl:if test="$extracted_name">
                  <field>
                    <xsl:attribute name="name">
                      <xsl:value-of select="concat($prefix, local-name(), '_', $role, $suffix)"/>
                    </xsl:attribute>
                    <xsl:value-of select="$extracted_name"/>
                  </field>
                </xsl:if>
              </xsl:when>
              <xsl:otherwise>
                <!-- FIXME: unrecognized type...  What to do? -->
              </xsl:otherwise>
            </xsl:choose>
          </xsl:when>
          <xsl:when test="$role and $name">
            <field>
              <xsl:attribute name="name">
                <xsl:value-of select="concat($prefix, local-name(), '_', @type, '_', $role, $suffix)"/>
              </xsl:attribute>
              <xsl:value-of select="$name"/>
            </field>
          </xsl:when>
          <xsl:when test="$name">
            <field>
              <xsl:attribute name="name">
                <xsl:value-of select="concat($prefix, 'name_', @type, '_unknown_role', $suffix)"/>
              </xsl:attribute>
              <xsl:value-of select="$name"/>
            </field>
          </xsl:when>
          <xsl:otherwise>
            <!-- TODO: No name... Dunno... -->
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>

      <xsl:for-each select=".//mods:note[@type='statement of responsibility']">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <!--don't bother with empty space-->
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'sor', $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <xsl:for-each select=".//mods:subject/* | .//mods:subject/mods:name/mods:namePart/*">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'subject', $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <xsl:for-each select=".//mods:physicalDescription/*">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, name(), $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <xsl:for-each select=".//mods:originInfo//mods:placeTerm[@type='text']">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'place_of_publication', $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <xsl:for-each select=".//mods:detail[@type='page number']/mods:number">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'page_num', $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>
    </xsl:template>

    <xsl:template match="pb:pbcoreDescriptionDocument">
      <xsl:param name="pid"/>
      <xsl:param name="prefix">pb_</xsl:param>  <!-- Prefix for field names -->
      <xsl:param name="single_suffix">_s</xsl:param>  <!-- Suffix for fields with a single value -->
      <xsl:param name="suffix">_ms</xsl:param>       <!-- Suffix for multivalued fields -->

      <!--  index dates (with types) -->
      <xsl:for-each select="pb:pbcoreAssetDate">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:variable name="dateType" select="translate(normalize-space(@dateType), ' ', '_')"/>

        <xsl:if test="$textValue">
          <xsl:variable name="dateValue">
	    <xsl:call-template name="get_ISO8601_date">
	      <xsl:with-param name="date" select="$textValue"/>
	    </xsl:call-template>
	  </xsl:variable>

          <field>
            <xsl:attribute name="name">
              <xsl:choose>
                <xsl:when test="$dateValue != '' and $dateType != ''">
                  <!-- XXX: seems like an odd assumption, to be able to create
                       a (single valued) date field when we have both a Solr-formatted
                       date value, and a date type... -->
                  <xsl:value-of select="concat($prefix, 'date_', $dateType, '_dt')"/>
                </xsl:when>
                <xsl:when test="$dateType">
                  <xsl:value-of select="concat($prefix, 'date_', $dateType, $suffix)"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="concat($prefix, 'date', $suffix)"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:attribute>

            <xsl:choose>
              <xsl:when test="$dateValue != ''">
                <xsl:value-of select="$dateValue"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:value-of select="$textValue"/>
              </xsl:otherwise>
            </xsl:choose>
          </field>

          <!-- created fields without end/start suffix -->
	  <xsl:choose>
	    <xsl:when test="substring-before($dateType, 'End')">
	      <field>
		<xsl:attribute name="name">
		  <xsl:value-of select="concat($prefix, 'date_', substring-before($dateType, 'End'), $suffix)"/>
		</xsl:attribute>
		<xsl:value-of select="$textValue"/>
	      </field>
	    </xsl:when>
	    <xsl:when test="substring-before($dateType, 'Start')">
	       <field>
		 <xsl:attribute name="name">
		   <xsl:value-of select="concat($prefix, 'date_', substring-before($dateType, 'Start'), $suffix)"/>
		 </xsl:attribute>
		 <xsl:value-of select="$textValue"/>
	       </field>
	     </xsl:when>
	  </xsl:choose>
        </xsl:if>
      </xsl:for-each>

      <!-- index all descriptions (with type) -->
      <xsl:for-each select="pb:pbcoreDescription">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:variable name="descType" select="translate(normalize-space(@descriptionType), ' ', '_')"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:choose>
                <xsl:when test="$descType">
                  <xsl:value-of select="concat($prefix, 'description_', $descType, $suffix)"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="concat($prefix, 'description', $suffix)"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <!-- index all titles (with type) -->
      <xsl:for-each select="pb:pbcoreTitle">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:variable name="titleType" select="normalize-space(@titleType)"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:choose>
                <xsl:when test="$titleType">
                  <xsl:value-of select="concat($prefix, 'title_', $titleType, $suffix)"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="concat($prefix, 'title', $suffix)"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
        <xsl:if test="$titleType and @annotation">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'title_', $titleType, '_annotation', $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="@annotation"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <!-- index all identifiers (with type) -->
      <xsl:for-each select="pb:pbcoreIdentifier[@source]">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'identifier_', @source, $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <!-- index all subjects -->
      <xsl:for-each select="pb:pbcoreSubject">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'subject', $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <!-- index all coverage portions -->
      <xsl:for-each select="pb:pbcoreCoverage/pb:coverage">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:variable name="coverageType" select="normalize-space(../pb:coverageType/text())"/>
        <xsl:if test="$textValue">
          <field>
             <xsl:attribute name="name">
              <xsl:choose>
                <xsl:when test="$coverageType">
                  <xsl:value-of select="concat($prefix, local-name(), '_' ,$coverageType, $suffix)"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

     <!-- index all Rights Summary -->
     <xsl:for-each select="pb:pbcoreRightsSummary/pb:rightsSummary">
       <xsl:variable name="textValue" select="normalize-space(text())"/>
       <xsl:variable name="rightsSource" select="normalize-space(@source)"/>
       <xsl:if test="$textValue">
         <field>
           <xsl:attribute name="name">
             <xsl:choose>
               <xsl:when test="$rightsSource"> 
                 <xsl:value-of select="concat($prefix, local-name(), '_' ,$rightsSource, $suffix)"/>
               </xsl:when>
               <xsl:otherwise>
                 <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
               </xsl:otherwise>
             </xsl:choose>
           </xsl:attribute>
           <xsl:value-of select="$textValue"/>
         </field>
          </xsl:if>
      </xsl:for-each>

      <!-- index the instantiations with a dedicated template -->
      <xsl:apply-templates select="pb:pbcoreInstantiation">
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
      </xsl:apply-templates>
    </xsl:template>

    <!-- index chunks of the instantiation itself -->
    <xsl:template match="pb:pbcoreInstantiation | pb:pbcoreInstantiationDocument">
      <xsl:param name="pid"/>
      <xsl:param name="prefix">pb_</xsl:param>
      <xsl:param name="single_suffix">_s</xsl:param>
      <xsl:param name="suffix">_ms</xsl:param>

      <xsl:if test="local-name()='pbcoreInstantiationDocument'">
        <xsl:variable name="parent">
          <xsl:call-template name="perform_query">
            <xsl:with-param name="query">
PREFIX fre: &lt;info:fedora/fedora-system:def/relations-external#&gt;
PREFIX fm: &lt;info:fedora/fedora-system:def/model#&gt;
SELECT ?parent
WHERE {
  &lt;<xsl:value-of select="concat('info:fedora/', $pid)"/>&gt; fre:isDerivativeOf ?parent ;
                                             fm:hasModel &lt;info:fedora/usc:mezzanineCModel&gt; ;
                                             fm:state fm:Active .
  ?parent fm:state fm:Active ;
          fm:hasModel &lt;info:fedora/usc:vroCModel&gt; .
}
            </xsl:with-param>
            <xsl:with-param name="lang">sparql</xsl:with-param>
          </xsl:call-template>
        </xsl:variable>

        <xsl:for-each select="xalan:nodeset($parent)/sparql:sparql/sparql:results/sparql:result/sparql:parent">
          <xsl:variable name="ds_url" select="concat(substring-before($FEDORA, '://'), '://', encoder:encode($FEDORAUSER), ':', encoder:encode($FEDORAPASS), '@', substring-after($FEDORA, '://') , '/objects/', substring-after(@uri, '/'), '/datastreams/PBCORE/content')"/>
          <xsl:message>URL:  <xsl:value-of select="$ds_url"/></xsl:message>
          <xsl:apply-templates select="document($ds_url)/pb:pbcoreDescriptionDocument">
            <xsl:with-param name="pid" select="substring-after(@uri, '/')"/>
            <xsl:with-param name="prefix" select="concat($prefix, 'parent_')"/>
            <xsl:with-param name="single_suffix" select="$single_suffix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
          </xsl:apply-templates>
        </xsl:for-each>
      </xsl:if>

      <xsl:for-each select="pb:instantiationIdentifier[@source='instantiation_title'] | pb:instantiationAnnotation[@annotationType='instantiation_title']">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'title', $single_suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <xsl:for-each select="pb:instantiationAnnotation[@annotationType='abstract']">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, @annotationType, $single_suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <xsl:for-each select="pb:instantiationDuration">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'duration', $single_suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>

      <xsl:for-each select="pb:instantiationDate">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'date', $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$textValue"/>
          </field>
        </xsl:if>
      </xsl:for-each>
    </xsl:template>

    <xsl:template match="text()">
      <xsl:param name="pid"/>
    </xsl:template>
    <xsl:template match="*">
      <xsl:param name="pid"/>
      <xsl:apply-templates>
        <xsl:with-param name="pid" select="$pid"/>
      </xsl:apply-templates>
    </xsl:template>

    <xsl:template name="perform_query">
      <xsl:param name="query" select="no_query"/>
      <xsl:param name="lang" select="'itql'"/>
      <xsl:param name="additional_params" select="''"/>
      <xsl:param name="RISEARCH" select="concat($FEDORA, '/risearch')"/>

      <xsl:variable name="encoded_query" select="encoder:encode(normalize-space($query))"/>
      <?xalan-doc-cache-off?>

      <xsl:variable name="query_url" select="concat($RISEARCH, '?query=', $encoded_query, '&amp;lang=', $lang, $additional_params)"/>
      <xsl:message>RI Query:  <xsl:value-of select="$query_url"/></xsl:message>
      <xsl:copy-of select="document($query_url)"/>
    </xsl:template>
</xsl:stylesheet>

