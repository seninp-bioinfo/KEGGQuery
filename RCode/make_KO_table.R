#
# last mod 2015-11-27
#
require(reshape)
require(plyr)
require(dplyr)
require(stringr)
#
require(RMySQL)
#
properties = read.table("/home/psenin/.funnymat/fmdb.properties", header = F, as.is = T)
db_credentials = data.frame(t(properties$V2), stringsAsFactors = F); names(db_credentials) = properties$V1
session <- dbConnect(MySQL(), host = db_credentials$host, dbname = db_credentials$db, 
                     user = db_credentials$user, password = db_credentials$password)
#
# retrieve all exisiting tags (i.e. datasets)
tags = dbGetQuery(session, "select * from hit_tags")
#
#
# CREATE TABLE temp_lots_of_data AS select * from thresholded_trimmed_noeu_hits where 
# (kh.identity>=60) and (kh.score>=96);
#
# define the function that counts all KOs for a dataset
tag_ko_count = function(sample_tag) {
  res = dbGetQuery(session, paste(
  "select gk.ko_id, count(kh.hit_id) from thresholded_trimmed_noeu_hits kh
  join genes_ko gk on gk.gene_idx=kh.gene_idx
  where kh.tag=",sample_tag," group by gk.ko_id;",sep = ""))
  colnames(res) = c("ko_id","count")
  res
}
#
# first dataset as a premier column
res <- tag_ko_count(tags[1,1])
names(res)[2] = tags[1,2]
#
# now, in the loop, query for the next tag and save the results as table
for (i in c(2:(length(tags$id))) ) {
  tag <- tags[i,] 
  sprintf("processing set %s\n", paste(tag[1],tag[2]))
  summary <- tag_ko_count(tag[1])
  res <- merge(res, summary, by.x = c("ko_id"), by.y = c("ko_id"), all = T)
  names(res)[length(names(res))] <- paste(tag[2])
  write.table(res, file = "table_progress.csv", quote = T, col.names = T, row.names = F, sep = "\t")
}
#
#
# define a function that extracts the KO description and first 10 MAPS
map_titles = function(ko_id) {
  
  desc <- dbGetQuery(session, paste(
  "select description from ko_description where ko_id=",shQuote(ko_id),";",sep = ""))
  
  maps <- dbGetQuery(session, paste(
  "select mt.title from ko_map km 
  join map_title mt on km.map_id=mt.map_id 
  where ko_id=", shQuote(substring(ko_id,4)),";",sep = ""))
  
  sequence <- rep("",10)
  if (dim(maps)[1] > 0) {
    maps <- as.vector(t(maps))
    if (length(maps) > 10) {
      sequence <- maps[1:10]
    } else {
      sequence[1:length(maps)] <- maps
    }
  }
  
  c(unlist(desc),unlist(sequence))
}
#
# test the function
map_titles("ko:K17989")
#
#
# extract these for all the KOs
kos <- res[,1]
#
tmp_set <- matrix( rep("",12), nrow = 1)
for (ko_id in kos) {
  tmp <- map_titles(ko_id)
  print(paste(ko_id))
  tmp_set <- rbind( tmp_set, matrix(c(ko_id,tmp),nrow = 1) )
}
#
# combine the both tables and write down the results
tmp_set <- tmp_set[-1,]
colnames(tmp_set) <- c("ko_id","ko_description",paste("pathway_",1:10,sep =  ""))
res2 <- merge(res, tmp_set, by.x = c("ko_id"), by.y = c("ko_id"), all = T)
write.table(res2,file = "table_all_ko_noeuc_tresholded_trimmed.csv", 
            quote = T, col.names = T, row.names = F, sep = "\t")
