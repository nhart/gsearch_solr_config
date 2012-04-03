<?xml version="1.0" encoding="UTF-8"?> 
<!--Alan 2011-02-17 -->
<!-- $Id: demoFoxmlToLucene.xslt 5734 2006-11-28 11:20:15Z gertsp $ -->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:exts="xalan://dk.defxws.fedoragsearch.server.GenericOperationsImpl"
    xmlns:islandora-exts="xalan://ca.upei.roblib.DataStreamForXSLT"
    exclude-result-prefixes="exts islandora-exts" xmlns:zs="http://www.loc.gov/zing/srw/"
    xmlns:foxml="info:fedora/fedora-system:def/foxml#" xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
    xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:mods="http://www.loc.gov/mods/v3"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
    xmlns:fedora="info:fedora/fedora-system:def/relations-external#"
    xmlns:rel="info:fedora/fedora-system:def/relations-external#"
    xmlns:fractions="http://vre.upei.ca/fractions/" xmlns:compounds="http://vre.upei.ca/compounds/"
    xmlns:critters="http://vre.upei.ca/critters/"
    xmlns:dwc="http://rs.tdwg.org/dwc/xsd/simpledarwincore/"
    xmlns:fedora-model="info:fedora/fedora-system:def/model#"
    xmlns:uvalibdesc="http://dl.lib.virginia.edu/bin/dtd/descmeta/descmeta.dtd"
    xmlns:pb="http://www.pbcore.org/PBCore/PBCoreNamespace.html"
    xmlns:uvalibadmin="http://dl.lib.virginia.edu/bin/admin/admin.dtd/">
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
    
    <xsl:variable name="PID" select="/foxml:digitalObject/@PID"/>
    <xsl:variable name="FULL_PID" select="concat('info:fedora/', $PID)"/>
    
    <xsl:variable name="docBoost" select="1.4*2.5"/>
    <!-- or any other calculation, default boost is 1.0 -->

    <xsl:template match="/">
      <update>
        <xsl:choose>
            <!-- The following allows only active FedoraObjects to be indexed. -->
          <xsl:when test="foxml:digitalObject/foxml:objectProperties/foxml:property[@NAME='info:fedora/fedora-system:def/model#state' and @VALUE='Active'] and not(foxml:digitalObject/foxml:datastream[@ID='METHODMAP'] or foxml:digitalObject/foxml:datastream[@ID='DS-COMPOSITE-MODEL']) and starts-with($PID,'')">
            <add>
              <doc>
                <xsl:attribute name="boost">
                    <xsl:value-of select="$docBoost"/>
                </xsl:attribute>
                <xsl:apply-templates mode="activeFedoraObject"/>
              </doc>
            </add>
          </xsl:when>
          <xsl:otherwise>
            <delete>
              <id><xsl:value-of select="$PID"/></id>
            </delete>
          </xsl:otherwise>
        </xsl:choose>
      </update>
    </xsl:template>

    <xsl:template match="foxml:objectProperties/foxml:property">
      <xsl:param name="prefix">fgs.</xsl:param>
      <xsl:param name="suffix"></xsl:param>
      
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, substring-after(@NAME,'#'), $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="@VALUE"/>
      </field>
    </xsl:template>
    
    <xsl:template match="foxml:datastream[@STATE='A']">
      <xsl:param name="mimetype" select="foxml:datastreamVersion[last()]/@MIMETYPE"/>
      
      <field name="fedora_active_datastream_state">
        <xsl:value-of select="@ID"/>
      </field>
    
      <!-- do different stuff, based on mimetype -->
      <xsl:choose>
        <xsl:when test="$mimetype='text/xml' or $mimetype='application/rdf+xml'"><!-- XML -->
          <xsl:choose>
            <xsl:when test="@CONTROL_GROUP='X'"><!-- XML, but not inline -->
              <xsl:apply-templates select="foxml:datastreamVersion[last()]/foxml:xmlContent"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="islandora-exts:getXMLDatastreamASNodeList($PID, $REPOSITORYNAME, @ID, $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:when>
        <xsl:when test="$mimetype='text/plain'">
          <xsl:call-template name="plaintext">
            <xsl:with-param name="text" select="islandora-exts:getDatastreamTextRaw($PID, $REPOSITORYNAME, @ID, $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
            <xsl:with-param name="dsid" select="@ID"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <!-- TODO: something logical -->
        </xsl:otherwise>
      </xsl:choose>
    </xsl:template>
    
    <xsl:template match="foxml:datastream[@STATE='I']">
      <xsl:param name="mimetype" select="foxml:datastreamVersion[last()]/@MIMETYPE"/>
      
      <field name="fedora_inactive_datastream_state">
        <xsl:value-of select="@ID"/>
      </field>
    </xsl:template>
    
    <xsl:template match="foxml:datastream[@STATE='D']">
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
              <xsl:value-of select="concat('dc_', local-name())"/>
            </xsl:attribute>
            <xsl:value-of select="$text"/>
          </field>
        </xsl:if>
      </xsl:for-each>
    </xsl:template>
    
    <xsl:template match="/foxml:digitalObject" mode="activeFedoraObject">
      <field name="PID" boost="2.5">
          <xsl:value-of select="$PID"/>
      </field>
      
      <xsl:apply-templates select="foxml:datastream"/>
      
      <!-- REFWORKS -/->
      <xsl:for-each select="foxml:datastream/foxml:datastreamVersion[last()]/foxml:xmlContent/reference/*">
          <field>
              <xsl:attribute name="name">
                  <xsl:value-of select="concat('refworks.', name())"/>
              </xsl:attribute>
              <xsl:value-of select="text()"/>
          </field>
      </xsl:for-each>-->


      <!-- Rights stream... Is this actually used anywhere? -/->
      <xsl:for-each select="foxml:datastream[@ID='RIGHTSMETADATA']/foxml:datastreamVersion[last()]/foxml:xmlContent//access/human/person">
          <field>
              <xsl:attribute name="name">access.person</xsl:attribute>
              <xsl:value-of select="text()"/>
          </field>
      </xsl:for-each>
      <xsl:for-each select="foxml:datastream[@ID='RIGHTSMETADATA']/foxml:datastreamVersion[last()]/foxml:xmlContent//access/human/group">
          <field>
              <xsl:attribute name="name">access.group</xsl:attribute>
              <xsl:value-of select="text()"/>
          </field>
      </xsl:for-each> -->

      <!-- Tagging...  Is this actually used anywhere? -/->
      <xsl:for-each select="foxml:datastream[@ID='TAGS']/foxml:datastreamVersion[last()]/foxml:xmlContent//tag">
        <field>
          <xsl:attribute name="name">tag</xsl:attribute>
          <xsl:value-of select="text()"/>
        </field>
        <field>
          <xsl:attribute name="name">tagUser</xsl:attribute>
          <xsl:value-of select="@creator"/>
        </field>
      </xsl:for-each>-->

      <!-- **** full text **** -/->

      <xsl:for-each select="foxml:datastream[@ID='OCR']/foxml:datastreamVersion[last()]">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat('OCR.', 'OCR')"/>
          </xsl:attribute>
          <xsl:value-of select="islandora-exts:getDatastreamTextRaw($PID, $REPOSITORYNAME, 'OCR', $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
        </field>
      </xsl:for-each>-->

      <!-- a managed datastream is fetched, if its mimetype 
         can be handled, the text becomes the value of the field. -->
      <!--<xsl:for-each select="foxml:datastream[@CONTROL_GROUP='M']">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat('dsm.', @ID)"/>
        </xsl:attribute>
        <xsl:value-of select="exts:getDatastreamText($PID, $REPOSITORYNAME, @ID, $FEDORASOAP, $FEDORAUSER, $FEDORAPASS, $TRUSTSTOREPATH, $TRUSTSTOREPASS)"/>
      </field>
    </xsl:for-each>-->
<!-- end of pbcore -->
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
        <xsl:choose>
          <!-- account for relationships to arbitrary URIs -->
          <xsl:variable name="subbed" select="substring-after(@rdf:resource, 'info:fedora/')"/>
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
      
      <xsl:apply-templates mode="rdf">
        <xsl:choose>
          <!-- probably adding in the dsid, since there's something after info:fedora/$PID -->
          <xsl:when test="substring-after(@rdf:about, $FULL_PID)">
            <xsl:variable name="dsid" select="substring-after(@rdf:about, concat($FULL_PID, '/'))"/>
            <xsl:with-param name="prefix" select="concat($prefix, $dsid, '_')"/>
            <xsl:with-param name="suffix" select="$suffix"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:with-param name="prefix" select="$prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:apply-templates>
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
      <xsl:param name="prefix">mods.</xsl:param>  <!-- Prefix for field names -->
      <xsl:param name="suffix"></xsl:param>       <!-- Suffix for field names -->
      
      <xsl:for-each select=".//mods:title[normalize-space(text())]">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($prefix, local-name(), $suffix)"/>
          </xsl:attribute>
          <xsl:value-of select="normalize-space(concat(../mods:nonSort/text(), ' ', text()))"/>
        </field>
      </xsl:for-each>
      
      <!-- Many elements get transformed in the same manner... -->
      <xsl:for-each select=".//mods:subTitle | .//mods:abstract | .//mods:genre | .//mods:form | .//mods:note[not(@type='statement of responsibility')] | .//mods:topic | .//mods:geographic | .//mods:caption | .//mods:extent | .//mods:accessCondition | .//mods:country | .//mods:county | .//mods:province | .//mods:region | .//mods:city | .//mods:citySection | .//mods:originInfo/mods:dateIssued | .//mods:originInfo/mods:dateCreated | .//mods:originInfo/mods:issuance | .//mods:physicalLocation | .//mods:identifier | .//mods:originInfo/mods:edition | .//mods:originInfo/mods:publisher">
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
        <xsl:variable name="role" select="normalize-space(mods:role/mods:roleTerm/text())"/>
        <xsl:variable name="name" select="normalize-space(mods:namePart/text())"/>
        
        <!-- They'll only get used if they have a role and namePart value, though -->
        <xsl:if test="$role and $name">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'name_', @type, '_', $role, $suffix)"/>
            </xsl:attribute>
            <xsl:value-of select="$name"/>
          </field>
        </xsl:if>
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

      <!--  added for newspaper collection  
      FIXME:  This should be in a separate MODS template...
      <xsl:if test="starts-with($PID, 'guardian')">
          <field>
              <xsl:attribute name="name">
                  <xsl:value-of select="'yearPublished'"/>
              </xsl:attribute>
              <xsl:value-of select="substring(//mods:dateIssued,1,4)"/>
          </field>
      </xsl:if>-->
    </xsl:template>
    
    <xsl:template match="pb:pbcoreDescriptionDocument">
      <xsl:param name="prefix">pb.</xsl:param>
      <xsl:param name="suffix"></xsl:param>
      
      <!-- index all descriptions (with type) -->
      <xsl:for-each select="pb:pbcoreDescription">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:variable name="descType" select="normalize-space(@descriptionType)"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:choose>
                <xsl:when test="$descType">
                  <xsl:value-of select="concat($prefix, 'description_', 'custom', $suffix)"/>
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
      
      <!-- index the instantiations with a dedicated template -->
      <xsl:apply-templates select="pb:pbcoreInstantiation">
        <xsl:with-param name="prefix" select="$prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
      </xsl:apply-templates>
    </xsl:template>
    
    <!-- index chunks of the instantiation itself -->
    <xsl:template match="pb:pbcoreInstantiation | pb:pbcoreInstantiationDocument">
      <xsl:param name="prefix">pb_</xsl:param>
      <xsl:param name="suffix">_s</xsl:param>
      
      <xsl:for-each select="pb:instantiationIdentifier[@source='instantiation_title']">
        <xsl:variable name="textValue" select="normalize-space(text())"/>
        <xsl:if test="$textValue">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, 'title', $suffix)"/>
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
              <xsl:value-of select="concat($prefix, @annotationType, $suffix)"/>
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
              <xsl:value-of select="concat($prefix, 'duration', $suffix)"/>
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
    
    <xsl:template match="*">
      <xsl:apply-templates/>
    </xsl:template>
</xsl:stylesheet>

