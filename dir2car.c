/*--------------------------------------------------------------------*/
/* Dir2Car                                                            */
/* by GienekP                                                         */
/* (c) 2025                                                           */
/*--------------------------------------------------------------------*/
#include <stdio.h>
#include <dirent.h>
/*--------------------------------------------------------------------*/
typedef unsigned char U8;
/*--------------------------------------------------------------------*/
char upper(char c)
{
	if ((c>='a') && (c<='z')) {c-=('a'-'A');};
	return c;
}
/*--------------------------------------------------------------------*/
void ATARIfilename(const char *filename, char *name, unsigned int size)
{
	unsigned int i,len=0;
	name[size-1]=0;
	for (i=0; i<(size-1); i++) {name[i]=' ';};
	while (filename[len]) {len++;};
	for (i=0; i<3; i++) {name[8+i]=upper(filename[len-3+i]);};
	if (len>12) {len=12;};
	for (i=0; i<(len-4); i++) {name[i]=upper(filename[i]);};
}
/*--------------------------------------------------------------------*/
unsigned int addFile(const char *filename, U8 *cardata, unsigned int carsize,
            const U8 *filedata, unsigned int filesize,
            unsigned int index, unsigned int pos)
{
	U8 header[16]={0,0,0,0,0,0,0,0, 0,0,0, 0,0,0, 0,0};
	unsigned int i,ret=0;
	
	header[11]=(filesize & 0xFF);
	header[12]=((filesize>>8) & 0xFF);
	header[13]=((filesize>>16) & 0xFF);
	
	header[14]=(((pos)%8192) / 256);
	header[15]=(((pos)/8192) & 0xFF);

	for (i=0; i<11; i++) {header[i]=filename[i];};
	
	if (((filesize+pos+256)<(carsize)) && (cardata[0]<255))
	{
		for (i=0; i<sizeof(header); i++) {cardata[1+index*sizeof(header)+i]=header[i];};
		for (i=0; i<filesize; i++) {cardata[pos+i]=filedata[i];};
		cardata[0]++;
		ret=(pos+(((filesize/256)+1)*256));
	};
	return ret;
}
/*--------------------------------------------------------------------*/
unsigned int loadFile(const char *filename, U8 *buf, unsigned int size)
{
	unsigned int ret=0;
	FILE *pf;
	pf=fopen(filename,"rb");
	if (pf)
	{
		ret=fread(buf,sizeof(U8),size,pf);
		fclose(pf);
	};
	return ret;
}
/*--------------------------------------------------------------------*/
unsigned int assignFiles(U8 *cardata, unsigned int carsize, const char *path)
{
	unsigned int ret=0,loop=1,i,j=0,pos=8192;
	struct dirent *file;
    char atarifilename[12];
    U8 data[512*1024];
    DIR *dir;
    if ((dir=opendir(path)))
    {
		printf("Read \"%s\"\n",path);   
        while (loop)
        {
			file=readdir(dir);
			if (file)
			{
				j=0; i=0;
				while (path[i]) 
				{
					data[j]=path[i];
					j++;
					i++;
				};
				data[j]='/';
				i=0;
				j++;
				while (file->d_name[i]) 
				{
					data[j]=file->d_name[i];
					j++;
					i++;
				};
				data[j]=0;
				if ((file->d_name[0])!='.')
				{
					i=loadFile((char *)data,data,sizeof(data));
					if (i)
					{
						ATARIfilename(file->d_name,atarifilename,sizeof(atarifilename));
						printf("%i) |%s| :$%05X - %i bytes\n",ret+1,atarifilename,pos,i);						
						pos=addFile(atarifilename,cardata,carsize,data,i,ret,pos);
						if (pos) {ret++;}
						else
						{
							ret=0;
							loop=0;
						};
					};
				};
			}
			else {loop=0;};
		};
        closedir(dir);
    };
	return ret;
}
/*--------------------------------------------------------------------*/
unsigned int saveCar(const char *filename, U8 *cardata, unsigned int carsize)
{
	U8 header[16]={0x43, 0x41, 0x52, 0x54, 0x00, 0x00, 0x00, 0x2A,
		           0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00};
	unsigned int ret=0,i,sum=0;
	FILE *pf;
	for (i=0; i<carsize; i++) {sum+=cardata[i];};
	header[8]=((sum>>24)&0xFF);
	header[9]=((sum>>16)&0xFF);
	header[10]=((sum>>8)&0xFF);
	header[11]=(sum&0xFF);
	pf=fopen(filename,"wb");
	if (pf)
	{
		i=fwrite(header,sizeof(U8),16,pf);
		if (i==16)
		{
			i=fwrite(cardata,sizeof(U8),carsize,pf);
			if (i==carsize) {ret=(16+i);};			
		};
		fclose(pf);
	};
	return ret;
}
/*--------------------------------------------------------------------*/
void prepareBANK(U8 *cardata, unsigned int carsize, const U8 *bankdata, unsigned int banksize)
{
	unsigned int i;
	for (i=0; i<banksize; i++)
	{
		cardata[i]=bankdata[i];
		cardata[carsize-banksize+i]=bankdata[i];
	};
}
/*--------------------------------------------------------------------*/
void clearCAR(U8 *car, unsigned int max)
{
	unsigned int i;
	for (i=0; i<max; i++) {car[i]=0xFF;};
}
/*--------------------------------------------------------------------*/
void dir2car(const char *filebank, const char *filecar, const char *path)
{
	U8 cardata[1024*1024];
	U8 bankdata[8192];
	unsigned int i;
	clearCAR(cardata,sizeof(cardata));
	if (loadFile(filebank,bankdata,sizeof(bankdata))==sizeof(bankdata))
	{
		printf("Set \"%s\" as first & last bank\n",filebank);
		prepareBANK(cardata,sizeof(cardata),bankdata,sizeof(bankdata));
		if (assignFiles(cardata,512*1024,path))
		{
			i=saveCar(filecar,cardata,sizeof(cardata));
			if (i>0) {printf("Save \"%s\" - %i bytes\n",filecar,i);}
			else {printf("Can't save \"%s\"\n",filecar);};
		}
		else
		{
			printf("\"%s\" doesn't exist\n",path); 
		};
	}
	else
	{
		printf("Can't find \"%s\"\n",filebank);
	};
}
/*--------------------------------------------------------------------*/
int main( int argc, char* argv[] )
{	
	printf("Dir2Car - ver: %s\n",__DATE__);
	if (argc==4) {dir2car(argv[1],argv[2],argv[3]);}
	else
	{
		printf("(c) GienekP\nuse:\n   dir2dcart bank.bin file.car directory\n");
		printf("where:\n   bank.bin - first & last bank\n");
		printf("   file.car - output file [42 - Atarimax 1 MB Flash cartridge (old)]\n");
		printf("   directory - AUTORUN.COM start automatically\n");
	};
	return 0;
}
/*--------------------------------------------------------------------*/
