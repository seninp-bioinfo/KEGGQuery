#
org_summary = function(tag) {
  res = dbGetQuery(session, paste("
         select org.code, org.tnum, org.name, org.lineage, count(kh.hit_id) from hits_noeu_trimmed kh
         join org_no_eukaryota org on org.id=kh.organism_idx
         where kh.tag=",tag," group by org.code;",sep=""))
  # take care about an empty record set
  #
  if(length(res)==0){
    res=matrix(rep(NA,5),ncol=5)
  }
  colnames(res)=c("code","tnum","name","lineage","count")
  res
}
res <- org_summary(tags[1,1])

# iterate over samples merging abundance counts as a column
#
for(i in c(2:(length(tags$id))) ){
  tag=tags[i,] 
  print(paste(format(Sys.time(), "%a %b %d %X %Y"), ", processing set ", tag[1], tag[2]))
  summary=org_summary(tag[1])
  # merge it here
  res=merge(res, summary, by.x=c("code","tnum","name","lineage"), 
            by.y=c("code","tnum","name","lineage"), all=T)
  names(res)[length(names(res))] = paste(tag[2])
  # save the progress
  fname=paste("taxonomy_table_progress.csv",sep="")
  write.table(res,file=fname, quote=T, col.names=T, row.names=F, sep="\t")
}

