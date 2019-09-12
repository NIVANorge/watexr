from prognos_tools.CloudInterface import CloudInterface
import yaml
import os

class Basin(CloudInterface):        

    initString ='''gcloud beta compute --project=nivacatchment instances create {instance}
--zone={region} 
--machine-type={machineType} 
--image={image}
--image-project={imageProject} 
--boot-disk-size={diskSize}
--boot-disk-device-name={instance}
--tags=http-server,https-server,postgres
'''     
    
    getBasinScript='''#!/bin/bash
startDir=$PWD
#Initializing schema for basin processing
read -r -d '' SQL <<- EOM
SELECT procedures.initializeStations();
SELECT procedures.addStations({2});
SELECT procedures.initializeResultsSchema('{0}');
SELECT procedures.createDataTable('{0}','dem');
SELECT procedures.createResultsTable('{0}','results');
EOM
echo $SQL | psql -d geonorway
# Processing basin for station with station_id id     
for id in {1}
do
  echo $id
  rm -rf Trash${{id}}
  mkdir Trash${{id}}
  cd Trash${{id}}

  #Exporting outlets from database as a shapefile
  pgsql2shp -g outlet -f stations${{id}} geonorway "select station_name, station_id, outlet  from {0}.demshp where station_id=${{id}}"
  
  #Computing basing using TauDEM. This produces a boolean tif where true means the cell is upstream of the outlet (i.e. part of the basin)
  n=`nproc`
  mpiexec -n $n gagewatershed -p "PG:dbname=geonorway schema={0} table=flow column=rast where='station_id=${{id}}' mode=2" -o stations${{id}}.shp -gw watershed${{id}}.tif

  #Transforming upstream pixels to shapefile
  gdal_polygonize.py -f "ESRI Shapefile" watershed${{id}}.tif basin${{id}}.shp

  #Uploading the basin shapefile to the database
  shp2pgsql -S -d -s 3035 basin${{id}}.shp {0}.dummy | psql -d geonorway    
  
  #Placing the basin shapefile in the results table    
  read -r -d '' SQL <<- EOM
      INSERT INTO {0}.resultsShp(station_id,station_name,basin)
      SELECT b.station_id, b.station_name, ST_MakeValid(ST_Multi(ST_Union(a.geom)))
      FROM {0}.stations AS b, {0}.dummy AS a
      WHERE b.station_id=${{id}}
      GROUP BY station_id, station_name;
EOM
  echo $SQL | psql -d geonorway 

  cd $startDir
  rm -rf Trash${{id}}
done

echo "DROP TABLE IF EXISTS {0}.dummy;" | psql -d geonorway

#Getting extent of basin and saving it to a txt file on the server
IFS=$'\\n' read -r -d '' SQL <<- EOM
    (SELECT station_name,Box2D(ST_Transform(St_Buffer(St_Envelope(basin),2000),4326)) FROM metno.resultsShp)
EOM
echo "\COPY "$SQL" TO '/home/jose-luis/results.txt' DELIMITER ';';" | psql -d geonorway
'''
    
    getGmapsLayers='''#!/bin/bash
#Getting all basins as geojson
IFS=$'\\n' read -r -d '' SQL <<- EOM
   (SELECT json_build_object(
                        'type', 'FeatureCollection',
                        'features', json_agg(
                            json_build_object(
                                'type',       'Feature',
                                'label',      station_name,
                                'geometry',   ST_AsGeoJSON(ST_ForceRHR(St_Transform(basin,4326)))::json,
                                'properties', jsonb_set(row_to_json(resultsShp)::jsonb,'{{basin}}','0',false)
                                )
                            )
                       )
                        FROM {0}.resultsShp)
EOM
echo "\COPY "$SQL" TO '/home/jose-luis/results.txt';" | psql -d geonorway

IFS=$'\\n' read -r -d '' SQL <<-EOM
   (SELECT a.station_name, st_x(st_transform(a.outlet,4326)),
    st_y(st_transform(a.outlet,4326)), st_area(b.basin)/1000000
    FROM {0}.demShp AS a
    INNER JOIN {0}.resultsShp AS b 
    ON a.station_id = b.station_id)
EOM

echo "\COPY "$SQL" TO '/home/jose-luis/dummy.txt' DELIMITER ';';" | psql -d geonorway
echo "" >> results.txt
cat dummy.txt >> results.txt
rm dummy.txt
'''
    
    getNcFiles='''#!/bin/bash
n=$((`nproc` * 2))
rm -rf ./tmp
mkdir ./tmp
ulimit -n 1024
cat {fileList} | parallel --eta --jobs $n -u --no-notice "fimex -c {cfgFile} --input.file={{}} --output.file=./tmp/{{/}} > /dev/null 2>&1"
ncrcat ./tmp/*.nc {out}
rm -rf ./tmp
'''
    
    vmScript=''
    
    def __init__(self,machineInfo):
        self.saveFolder = './'
        self.vmScript=''
        super().__init__(machineInfo)
        
    def instantiate(self,fabfile=''):
        self.instantiationString = Basin.initString.format(**self.machineInfo)#self.instance,self.region,self.machineType)
#         display(self.instantiationString)
        
#         display(Basin.initString)
        super().instantiate(fabfile)
        
    def infoToString(self,d):
        l = [ "'"+d[key]+"'" if isinstance(d[key],str) else str(d[key])  for key in ['station_name','station_id','longitude','latitude','buffer','epsg','limits']]
        return 'row(' + ','.join(l) +')::station_info'
    
    def yamlToInfoArray(self,yamlFile):
        allStations = list()
        stations = yaml.safe_load(open(yamlFile))
        for i in stations:
            data = i['station']
            if self.isNumber(data['buffer']):
                data['limits'] = ''
            else:
                data['buffer'] = -9999
            allStations.append(data)
        return 'ARRAY[' +  ','.join([self.infoToString(i) for i in allStations]) + ']', ' '.join([str(i['station_id']) for i in allStations]);
    
        
    def getBasinLayers(self,yamlFile,schema,saveFolder='./'):
        self.saveFolder = saveFolder
        if (self.saveFolder != './'):
            display('Directory should be created')            
            self.callPopen('rm -rf {}'.format(self.saveFolder))
            self.callPopen('mkdir -p {}'.format(self.saveFolder))
        print("Gonna create the getBasin.sh file")
        array,ids =  self.yamlToInfoArray(yamlFile)
        basinScript = os.path.join(saveFolder,'getBasin.sh')
        print(basinScript)
        with open(basinScript,'w') as f:
            f.write( Basin.getBasinScript.format(schema,ids,array) )
        #Delineating basin on server
        cmd = 'fab -f {} runScript:{},{},{}'.format(self.fabfile,basinScript,True,os.path.join(saveFolder,'box.txt'))
        print(cmd)
        self.callPopen(cmd)

        #Getting gmaps layers
        gmapScript = os.path.join(saveFolder,'gmaps.sh')
        with open(gmapScript,'w') as f:
            f.write(Basin.getGmapsLayers.format(schema) )   
        cmd = 'fab -r {} runScript:{},{},{}'.format(self.fabfile,gmapScript,True,os.path.join(saveFolder,'gmaps.txt'))
        self.callPopen(cmd)

        

    def getNcDataForBox(self,fileList,cfgFile,out):
        dummy = {}
        dummy['fileList'] = os.path.basename(fileList)
        dummy['cfgFile'] =  cfgFile
        dummy['out'] = out
        display(Basin.getNcFiles,dummy)
        with open('getDataForBox.sh','w') as f:
            f.write( Basin.getNcFiles.format(**dummy) )
        cmd = 'fab -r {} getDataForBox:{},{},{},{}'.format(self.fabfile,
                                                           'getDataForBox.sh',
                                                           fileList,
                                                           cfgFile,
                                                           out
                                                          )
        display(cmd)
        self.callPopen(cmd,overwrite=True,additionalDisplay=out)
        
    def runScript(self,saveFolder='./',scriptName='script.sh'):
        self.saveFolder=saveFolder
        if (self.saveFolder != './'):
#             self.callPopen('rm -rf {}'.format(self.saveFolder))
            self.callPopen('mkdir -p {}'.format(self.saveFolder))
        script = os.path.join(saveFolder,scriptName)
        self.callPopen('rm -p {}'.format(script))        
        with open(script,'w') as f:
            f.write( self.vmScript )
        cmd = 'fab -r {} runScript:{}'.format(self.fabfile,
                                             script
                                             )
        display(cmd)
        self.callPopen(cmd,overwrite=True)