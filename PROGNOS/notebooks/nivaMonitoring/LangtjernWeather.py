__author__ = 'Roar Brenden'


import AquaMonitor
import datetime
import pandas as pd

#root = "/Users/roar/"

def getLangtjernData(username, password, root, fromDate, toDate) :
    
    weatherFile = 'langtjernWeather.csv'
    lakeFile = 'langtjernLake.csv'
    outletFile = 'langtjernOutlet.csv'
    inletFile = 'langtjernInlet.csv'
    chemistryFile = 'langtjernChemistry.csv'
    inletFileTOC = 'langtjernTOCInlet.csv'

    
    
    fromDate = datetime.datetime.strptime(fromDate,"%Y/%m/%d").date()
    toDate = datetime.datetime.strptime(toDate,"%Y/%m/%d").date()
    expires = datetime.date.today() + datetime.timedelta( days=1 )
    
    token = AquaMonitor.login("AquaServices", username, password)

    def make_file(title, filename, stationid, datatype) :
        where = "sample_date>=" + datetime.datetime.strftime(fromDate, '%d.%m.%Y') \
                + " and sample_date<" + datetime.datetime.strftime(toDate, '%d.%m.%Y') \
                + " and datatype=" + datatype

        data = {
            "Expires": expires.strftime('%Y.%m.%d'),
            "Title": title,
            "Files":[{
                "Filename": filename,
                "ContentType":"text/csv"}],
            "Definition":{
                "Format":"csv",
                "StationIds": [ stationid ],
                "DataWhere": where
            }
        }
        resp = AquaMonitor.createDatafile(token, data)
        return resp["Id"]


    def download_file(id, filename) :
        archived = False
        while not archived:
            resp = AquaMonitor.getArchive(token, id)
            archived = resp.get("Archived")
        path = root + filename
        AquaMonitor.downloadArchive(token, id, filename, path)


    weatherFileId = make_file('Langtjern weather', weatherFile, 62040, 'Air')
    lakeFileId = make_file('Langtjern lake', lakeFile, 50472, 'Water')
    outletFileId = make_file('Langtjern outlet',outletFile, 51356, 'Water')
    inletFileId = make_file('Langtjern inlet', inletFile, 63098, 'Water')
    chemistryFileId = make_file('Langtjern chemistry',chemistryFile, 37928, 'Water')
    inletFileTOCId = make_file('Langtjern TOC', inletFileTOC, 37933, 'Water')
    
    download_file(weatherFileId, weatherFile)
    download_file(lakeFileId, lakeFile)
    download_file(inletFileId, inletFile)
    download_file(outletFileId, outletFile)
    download_file(chemistryFileId, chemistryFile)  
    download_file(inletFileTOCId, inletFileTOC)

    
    allData = {}
    
    #Putting the data into the right format
    #First placing dataframes in a dictionary
    allData['weather']   = pd.read_csv(root + weatherFile,     delimiter=';', encoding='utf-16')
    allData['lake']      = pd.read_csv(root + lakeFile,        delimiter=';', encoding='utf-16')
    allData['outlet']    = pd.read_csv(root + outletFile,      delimiter=';', encoding='utf-16')
    allData['inlet']     = pd.read_csv(root + inletFile,       delimiter=';', encoding='utf-16')
    allData['TOC']       = pd.read_csv(root +  inletFileTOC,   delimiter=';', encoding='utf-16')
    allData['chemistry'] = pd.read_csv(root +  chemistryFile,  delimiter=';', encoding='utf-16')
    
    #Make the index of the dataframes a timestamp, storing only float data (hopefully measurements)
    for key, i in allData.items():
        i.set_index(pd.to_datetime(i["SampleDate_dato"].map(str) + ' ' + i["SampleDate_tid"],format = '%d.%m.%Y %H:%M:%S'),inplace=True)
#         i.set_index(pd.to_datetime(i["SampleDate_dato"].map(str) + ' ' + i["SampleDate_tid"],format = '%d.%m.%Y %H:%M:%S',utc=True),inplace=True)
        allData[key] = i.loc[:,i.dtypes == 'float64']
    return allData


def getLangtjernData(username, password, root, fromDate, toDate, sid, medium) :
    
    dataFile = 'data.csv'
       
    fromDate = datetime.datetime.strptime(fromDate,"%Y/%m/%d").date()
    toDate = datetime.datetime.strptime(toDate,"%Y/%m/%d").date()
    expires = datetime.date.today() + datetime.timedelta( days=1 )
    
    token = AquaMonitor.login("AquaServices", username, password)

    def make_file(title, filename, stationid, datatype) :
        where = "sample_date>=" + datetime.datetime.strftime(fromDate, '%d.%m.%Y') \
                + " and sample_date<" + datetime.datetime.strftime(toDate, '%d.%m.%Y') \
                + " and datatype=" + datatype

        data = {
            "Expires": expires.strftime('%Y.%m.%d'),
            "Title": title,
            "Files":[{
                "Filename": filename,
                "ContentType":"text/csv"}],
            "Definition":{
                "Format":"csv",
                "StationIds": [ stationid ],
                "DataWhere": where
            }
        }
        resp = AquaMonitor.createDatafile(token, data)
        return resp["Id"]


    def download_file(id, filename) :
        archived = False
        while not archived:
            resp = AquaMonitor.getArchive(token, id)
            archived = resp.get("Archived")
        path = root + filename
        AquaMonitor.downloadArchive(token, id, filename, path)


    dataFileId = make_file('Data',dataFile, sid, medium)

    download_file(dataFileId, dataFile)

    data = pd.read_csv(root + dataFile,     delimiter=';', encoding='utf-16')
    
    data.set_index(pd.to_datetime(data["SampleDate_dato"].map(str) + ' ' + data["SampleDate_tid"],format = '%d.%m.%Y %H:%M:%S'),inplace=True)
#     data = data.astype('float64')

    return data