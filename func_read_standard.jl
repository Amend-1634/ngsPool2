#func_read_plot2(2020/8/12)
using CSV, CodecZlib, Plots, DelimitedFiles, Plots.PlotMeasures, DataFrames

#form: :chrom(string), :position(Int), :algorithm_software(float)]
#name.extension

#standard input form
# "$name.txt" #population allele frequency simulated
# "$name.snp.gz" #estimation of ngsPool with SNP calling
# "$name.sync" #Popoolation2
# "$name.snape"
# "$name.varscan"

#use the functions
# df_snp=read_ngsPool_snp(name)
# df_true = read_true(name)
# df_popoo = read_p2(name)
# varscan_p=read_varscan(name)
# varscan_nallele= read_nallele_varscan2(name) #mumber of reference or alternative allele
# snape_p, snape_nallele = read_snape(name)

#read the gzipped file of ngsPool with SNP calling
function read_ngsPool_snp(name) #all are SNP calling
    if occursin("snp", name)
        maf_snp = open(GzipDecompressorStream, "$name.snp.gz", "r") do stream #estimated
            CSV.read(stream) #output to df
        end #1000 rows--sites, maf as dataframe
    else
        maf_snp = open(GzipDecompressorStream, "$name.gz", "r") do stream #estimated
            CSV.read(stream) #output to df
        end #1000 rows--sites, maf as dataframe
    end
    df_snp = hcat(maf_snp[!,1], maf_snp[!, [:position, :maf,:freqMax, :freqE]])

    rename!(df_snp, [:chrom, :position, :GSS_ngsPool,:freqMax_ngsPool, :freqE_ngsPool])
     #Golden-section search (GSS); maf with maximum SFS likelihood, expected maf with SFS likelihood
    return df_snp #dataframe
end

#read the gzipped file of ngsPool with SNP calling
function read_ngsPool_snp2(name) #no snp in the name
    maf_snp = open(GzipDecompressorStream, "$name.gz", "r") do stream #estimated
        CSV.read(stream) #output to df
    end #1000 rows--sites, maf as dataframe

    df_snp = hcat(maf_snp[!,1], maf_snp[!, [:position, :maf]]) #:freqMax, :freqE, those three are too close so

    rename!(df_snp, [:chrom, :position, :GSS_ngsPool]) #,:freqMax_ngsPool, :freqE_ngsPool
     #Golden-section search (GSS); maf with maximum SFS likelihood, expected maf with SFS likelihood
    return df_snp #dataframe
end

# cd("C:\\simu_raw\\sig")
# name="simu-1-100-0.1"
# df_snp=read_ngsPool_snp(name)

#read txt file output while simulating pool data
function read_true(name)
    # if occursin("txt", name)
        daf = readdlm("$name.txt", '\t', String, '\n') #true #daf as matrix
        daf_1 = daf[:, 1]
        daf_2 = parse.(Int64, daf[:, 2])
        daf_end = parse.(Float64, daf[:, 5])#wrong, true maf is in 5th column, the end column is the simple reads proportion of reads(no meaning)
        df_true = DataFrame(chrom = daf_1, position = daf_2, true_maf = daf_end)
    # elseif occursin("gz", name)
    #     daf = open(GzipDecompressorStream, name, "r") do stream #estimated
    #         CSV.read(stream, header=false) #output to df
    #     end #1000 rows--sites, maf as dataframe
    #     df_true = daf[!,[1,2,5]]
    #     df_true = rename!(df_true, [:chrom, :position, :true_maf])
    # end
    return df_true
end

# cd("C:\\simu_raw\\sig")
# name="test-1-100"
# df_true = read_true(name)

# df_snp2=innerjoin(df_snp, df_true, on=[:chrom, :position])
# df_snp3=sort(df_snp2, :true_maf)

# mtx_snp3=convert(Matrix,df_snp3[3:end])
# scatter(mtx_snp3[:,end], mtx_snp3[:,1:end-1])
# plot(mtx_snp3)
# #differ but very close

#read the output of Popoolation2
function read_p2(name) #Popoolation2
    # println("$name.sync")
    daf = readdlm("$name.sync", '\t', String, '\n')
    daf_count = daf[:, 4]
    nsite = length(daf_count)
    mafs = zeros(nsite)

    for i in 1:length(daf_count)
        count = parse.(Int, split(daf_count[i], ":"))
        maf = sort(count)[end-1]/sum(count) #minor allele frequency
        mafs[i] = maf
    end
    daf_2 = parse.(Int, daf[:,2])
    df_final = DataFrame(chrom=daf[:,1], position=daf_2, popoo=mafs)
    return df_final
end

# cd("C:\\Fraca_raw\\out")
# name="PopA_pooled_java"
# df_popoo = read_p2(name)
#
# count(i->i!=0, df_popoo[:,3]) #SNP calling: 7870 out of 44856


#read varscan estimation file and output Minor allele frequencies
function read_varscan(name) #input such as "PopB_pooled_L4"
    raw=CSV.read("$name.varscan", header=true)

    #filter out the sites filtered by min coverage
    NA_row=[]
    all_row=collect(1:length(raw[!,end]))
    for i in all_row
        if occursin(r":-:-:-:-", raw[i,end]) #filter out the row not called
            push!(NA_row, i)
        end
    end
    left_row = filter(x->!(x in NA_row), eachindex(all_row))
    raw=raw[left_row,:]

    cross_samp = raw[:, 5]
    each_sample = raw[:, end]
    nr = length(cross_samp) #nrow
    maf_p_mtx = Array{String}(undef,nr,4) #1,2col cross-sample; 3,4 each sample

    for i in 1:nr
        maf_p_mtx[i,[1,2]]=split(cross_samp[i], ":")[[5,6]] #maf and fisher's exact test(FET) p value
        maf_p_mtx[i,[3,4]]=split(each_sample[i], ":")[[5,6]] #maf and fisher's exact test(FET) p value
        #maf frequency and Fisher's exact test p value
    end

    #convert string to decimals
    maf_p_mtx2=Array{Float64}(undef,nr,4)
    for i in 1:nr, j in [1,3]
        # println([i, j])
        # println(maf_p_mtx[i, j])
        # println(each_sample[i, end])
        maf_p_mtx2[i, j] = parse(Float64, chop(maf_p_mtx[i, j]))/100
    end

    for i in 1:nr
        p = maf_p_mtx[i, 2]
        maf_p_mtx2[i, 2] = parse(Float64, p)
    end

    maf_p_mtx3=DataFrame(maf_p_mtx2, [:cross_samp_maf, :cross_samp_p, :each_samp_maf, :each_samp_p])
    maf_p_mtx_final=hcat(raw[:,1:2], maf_p_mtx3)
    rename!(maf_p_mtx_final, [:chrom,:position,:cross_samp_maf, :cross_samp_p, :each_samp_maf, :each_samp_p])

    return maf_p_mtx_final
    end

# cd("C:\\Fraca_raw\\out")
# using CSV, DataFrames
# name="PopB_pooled_L2" #all [33,3] only L2 [34,3]
# name="PopB_pooled_L4"
# varscan_p=read_varscan(name)
# #check the - problem############################
# raw=CSV.read("$name.varscan", header=true)
# for i in 1:length(raw[!,end])
#     if occursin(r":-:-:-:-", raw[i,end])
#         println(i)
#     end
# end
#
# for i in 1:length(raw[!,5])
#     if occursin(r":-:-:-:-", raw[i,end])
#         println(i)
#     end
# end
# #N:2:-:-:-:- G:11:0:11:100%:1.4176E-6 #what amendment after renewing? why? before it can function
# #same sites absent in each-sample and cross-sample test(speculate due to min coverage 4)
# #lose around 20/98 sites
# #consider set the minor allele count as 2?
# #and ignore those filtered sites (if)
################################################

#read varscan estimation file and output the number of reads of varscan
function read_nallele_varscan2(name) #input such as "PopB_pooled_L4"
    raw=CSV.read("$name.varscan", header=true)

    #filter out the sites filtered by min coverage
    NA_row=[]
    all_row=collect(1:length(raw[!,end]))
    for i in all_row
        if occursin(r":-:-:-:-", raw[i,end])
            push!(NA_row, i)
        end
    end
    left_row = filter(x->!(x in NA_row), eachindex(all_row))
    raw=raw[left_row, :]

    cross_samp = raw[:,5]
    each_sample = raw[:,end]

    nr = length(cross_samp) #nrow
    nallele_mtx=DataFrame(Array{Int}(undef, nr, 4), [:ref_crs_varscan, :alt_crs_varscan,:ref_each_varscan, :alt_each_varscan])

    #1,2col cross-sample; 3,4 each sample

    for i in 1:nr , j in [3,4]
        c_i=split(cross_samp[i], ":")[j][1]
        nallele_mtx[i, j-2]=parse(Int, c_i)
        #maf frequency and Fisher's exact test p value
    end

    for i in 1:nr , j in [3,4]
        e_i=split(each_sample[i], ":")[j][1]
        nallele_mtx[i, j]=parse(Int, e_i)
        #maf frequency and Fisher's exact test p value
    end

    nallele_mtx=hcat(raw[:,1:2], nallele_mtx)
    rename!(nallele_mtx, [:chrom,:position,:ref_crs_varscan, :alt_crs_varscan,:ref_each_varscan, :alt_each_varscan])
    return nallele_mtx
    end

# cd("C:\\Fraca_raw\\out")
# using CSV, DataFrames
# name="PopB_pooled_L4"

# varscan_nallele= read_nallele_varscan2(name) #mumber of reference or alternative allele

#read the estimation file of Snape and output two files (_p as MAFs, _num as the number of reads)
function read_snape(name)
    # name="PopB_pooled_L4"
    raw=CSV.read("$name.snape", header=false)
    if isempty(raw)
        println("$name.snape is empty")
        return DataFrame(), DataFrame()
    end

    final_p=raw[:,[1,2,end]]
    rename!(final_p, [:chrom,:position,:maf_snape])

    final_num=raw[:,[1,2,3,4]]
    rename!(final_num, [:chrom,:position,:ref_snape,:alt_snape])

    return final_p, final_num
end

# cd("C:\\Fraca_raw\\out")
# using CSV, DataFrames
# name="PopB_pooled_L4"
# snape_p, snape_nallele = read_snape(name)

#read varscan

##Root mean square error with input in different data types
RMSE(maf::Float64, true_maf::Float64) = sqrt(sum( (maf .- true_maf).^2 )/ length(maf) )
RMSE(maf::Float64, true_maf::Missing) = missing
RMSE(maf::Missing, true_maf::Float64) = missing
RMSE(maf::Missing, true_maf::Missing) = missing

#calculate Mean percentage error
#input as two numbers
MPE(maf::Float64, true_maf::Float64) = (maf - true_maf) / true_maf
    #delete the entry with true_maf=0, might not be the standard MPE methods

#input as two vectors
function MPE(maf::Array, true_maf::Array) #input two vectors and get one value (vectors have to be the replicates)
    if !ismissing(maf) && !ismissing(true_maf)
        nzero = count(iszero, true_maf)
        mpe_itr = (maf .- true_maf) ./ true_maf
        mpe_itr[true_maf .== 0] .= 0
        mpe = sum(mpe_itr) / (size(maf)[1]-nzero) #not include the entry with true as 0
        return mpe
    else
        return missing
    end
end

################################################################################
#The annotation of the outputs of ngsPool, Popoolation2, Snape and VarScan
################################################################################

##ngsPool output######################################
#the first row:
 # chrom   position        reference       nonreference    major   minor   lrtSNP  lrtBia  lrtTria maf     freqMax freqE
#corresponding annotation:
   #chromosome, position,reference allele, nonreference allele, major allele, minor allele,
   #likelihood ration test statistic (lrt) of SNP, lrt of biallelic site, lrt of triallelic,
   #minor allele frequency (from Golden Section Search),
   #Maximum likelihood estimation (from SFS)
   #Expected estimation (from SFS)

##Popoolation2######################################
# (source: https://sourceforge.net/p/popoolation2/wiki/Tutorial/)
# Sample of a synchronized file:
#
# 2R  2302    N   0:7:0:0:0:0 0:7:0:0:0:0
# 2R  2303    N   0:8:0:0:0:0 0:8:0:0:0:0
# 2R  2304    N   0:0:9:0:0:0 0:0:9:0:0:0
# 2R  2305    N   1:0:9:0:0:0 0:0:9:1:0:0
# col1: reference contig
# col2: position within the refernce contig
# col3: reference character
# col4: allele frequencies of population number 1
# col5: allele frequencies of population number 2
# coln: allele frequencies of population number n
# The allele frequencies are in the format A:T:C:G:N:del, i.e: count of bases 'A',
# count of bases 'T',... and deletion count in the end (character '*' in the mpileup)

##Snape output######################################
#10 fields:
    #1. chr: genomic coordinates
    #2. position along the chronosome
    #3. ref nucleotides
    #4. num of minor (alternative) nucleotide
    #5. mean quality of the reference nucleotide
    #6. mean quality of the alternative nucleotide
    #7. first and second most frequent nucleotides in the pileup
    #8. 1-p(0), p(f) as the probability distribution function for the maf (f)
    #9. p(1)
    #10. mean value of f

    # what's num of minor (alternative) nucleotide for?
    # 5.6. are around 60 and 70, seems unrealistic(0.0001% error rate) compared to
        #(Kofler et al., 2011) Popoolation, should be around 20 to 30
        #what's the unit?
    # 1-p(0)-p(1) is the probability of SNP? Any threshold?
    # why 1-p(0) can be greater than 1? (no matter accumulative or density)
    # can 10. be compared with the expected mean in ngsPool?



##Varscan#############################################
# OUTPUT
# 	Tab-delimited SNP calls with the following columns:
# 	1.Chrom		chromosome name
# 	2.Position	position (1-based)
# 	3.Ref			reference allele at this position
# 	4.Var			variant allele observed
# 	5.PoolCall	Cross-sample call using all data (Cons:Cov:Reads1:Reads2:Freq:P-value)
# 			1)Cons - consensus genotype in IUPAC format
# 			2)Cov - total depth of coverage
# 			3)Reads1 - number of reads supporting reference
# 			4)Reads2 - number of reads supporting variant
# 			5)Freq - the variant allele frequency by read count
##5.5)lower false discovery rate in SNP calling
# 			6)P-value - FET p-value of observed reads vs expected non-variant
# 	6.StrandFilt	Information to look for strand bias using all reads (R1+:R1-:R2+:R2-:pval)
# 			R1+ = reference supporting reads on forward strand
# 			R1- = reference supporting reads on reverse strand
# 			R2+ = variant supporting reads on forward strand
# 			R2- = variant supporting reads on reverse strand
# 			pval = FET p-value for strand distribution, R1 versus R2
# 	7.SamplesRef	Number of samples called reference (wildtype)
# 	8.SamplesHet	Number of samples called heterozygous-variant
# 	9.SamplesHom	Number of samples called homozygous-variant
# 	10.SamplesNC	Number of samples not covered / not called
# 	11.SampleCalls	The calls for each sample in the mpileup, space-delimited
#     			Each sample has six values separated by colons:
# 			Cons - consensus genotype in IUPAC format
# 			Cov - total depth of coverage
# 			Reads1 - number of reads supporting reference
# 			Reads2 - number of reads supporting variant
# 			Freq - the variant allele frequency by read count
##11.5)collect as
# 			P-value - FET p-value of observed reads vs expected non-variant
                    #fisher's exact test?
