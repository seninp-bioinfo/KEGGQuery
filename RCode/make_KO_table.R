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
#
tags = dbGetQuery(session, "select * from hit_tags")
#
#
# CREATE TABLE temp_lots_of_data AS select * from thresholded_trimmed_noeu_hits where 
# (kh.identity>=60) and (kh.score>=96);
#
tag_ko_count = function(sample_tag) {
  res = dbGetQuery(session, paste("
  select gk.ko_id, count(kh.hit_id) from thresholded_trimmed_noeu_hits kh
  join genes_ko gk on gk.gene_idx=kh.gene_idx
  where kh.tag=",sample_tag," group by gk.ko_id;",sep=""))
  colnames(res)=c("ko_id","count")
  res
}

res <- tag_ko_count(tags[1,1])
names(res)[2] = tags[1,2]
for(i in c(2:(length(tags$id))) ){
  tag=tags[i,] 
  sprintf("processing set %s\n", paste(tag[1],tag[2]))
  summary=tag_ko_count(tag[1])
  res=merge(res, summary, by.x=c("ko_id"), by.y=c("ko_id"), all=T)
  names(res)[length(names(res))] = paste(tag[2])
  write.table(res,file="table_progress.csv", quote=T, col.names=T, row.names=F, sep="\t")
}


