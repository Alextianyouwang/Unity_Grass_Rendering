using UnityEngine;
public class TileChunkDispatcher
{
    public TileChunk[] Chunks { get; private set; }
    private TileData _tileData;
    private TileClumpParser _tileClumpParser;

    private ComputeShader _spawnOnTileShader;
    private ComputeBuffer _rawSpawnBuffer; 

    private Mesh[] _spawnMesh;
    private Material _spawnMeshMaterial;
    private Camera _renderCam;
    struct SpawnData
    {
        Vector3 positionWS;
        float hash;
        Vector4 clumpInfo;
        float density;
        float wind;
    };
    private SpawnData[] _spawnData;
    private int _tileCount;

    private bool _smoothPlacement;

    public TileChunkDispatcher(Mesh[] spawnMesh, Material spawmMeshMat, TileData tileData, Camera renderCam, bool smoothPlacement)
    {
        _spawnMesh = spawnMesh;
        _spawnMeshMaterial = spawmMeshMat;
        _tileData = tileData;
        _renderCam = renderCam;
        _smoothPlacement = smoothPlacement;
    }


    public void InitialSpawn()
    {
        _spawnOnTileShader = GameObject.Instantiate((ComputeShader)Resources.Load("CS_InitialSpawn"));
        _tileCount = _tileData.TileGridDimension * _tileData.TileGridDimension;
        int instancePerTile = TileGrandCluster._SpawnSubdivisions * TileGrandCluster._SpawnSubdivisions;

        _spawnData = new SpawnData[_tileCount * instancePerTile];
        _rawSpawnBuffer = new ComputeBuffer(_tileCount * instancePerTile, sizeof(float) * 10);
        _rawSpawnBuffer.SetData(_spawnData);

        _spawnOnTileShader.SetInt("_NumTiles", _tileCount);
        _spawnOnTileShader.SetInt("_Subdivisions", TileGrandCluster._SpawnSubdivisions);
        _spawnOnTileShader.SetInt("_NumTilesPerSide", _tileData.TileGridDimension);
        _spawnOnTileShader.SetBool("_SmoothPlacement", _smoothPlacement);

        _spawnOnTileShader.SetBuffer(0, "_VertBuffer", _tileData.VertBuffer);
        _spawnOnTileShader.SetBuffer(0, "_TypeBuffer", _tileData.TypeBuffer);
        _spawnOnTileShader.SetBuffer(0, "_SpawnBuffer", _rawSpawnBuffer);
        _spawnOnTileShader.Dispatch(0, Mathf.CeilToInt(_tileCount / 128f), 1, 1);
    }

    private ComputeBuffer ProcessWithClumpData() 
    {
        _tileClumpParser = new TileClumpParser(
            _rawSpawnBuffer,
            _tileData.TileGridDimension,
            _tileData.TileSize,
            _tileData.TileGridCenterXZ - Vector2.one * _tileData.TileGridDimension * _tileData.TileSize * 0.5f
            );
        _tileClumpParser.ParseClump();
        return _tileClumpParser.ShareSpawnBuffer();
    }
    public void InitializeChunks() 
    {
        _rawSpawnBuffer =  ProcessWithClumpData();
        int chunksPerSide = TileGrandCluster._ChunksPerSide;
        Chunks = new TileChunk[chunksPerSide * chunksPerSide];
        int chunkDimension = _tileData.TileGridDimension / chunksPerSide;
        int totalInstancePerChunk = chunkDimension * chunkDimension * TileGrandCluster._SpawnSubdivisions * TileGrandCluster._SpawnSubdivisions;
        float chunkSize = _tileData.TileGridDimension * _tileData.TileSize / chunksPerSide;
        Vector2 botLeft = _tileData.TileGridCenterXZ - chunkSize * chunksPerSide * Vector2.one / 2 + Vector2.one * chunkSize / 2;
        
        for (int x = 0; x < chunksPerSide; x++)
        {
            for (int y = 0; y < chunksPerSide; y++) 
            {
                SpawnData[] spawnDatas = new SpawnData[totalInstancePerChunk];
                ComputeBuffer chunkBuffer = new ComputeBuffer(totalInstancePerChunk, sizeof(float) * 10);
                chunkBuffer.SetData(spawnDatas);
                _spawnOnTileShader.SetInt("_ChunkIndexX", x);
                _spawnOnTileShader.SetInt("_ChunkIndexY", y);
                _spawnOnTileShader.SetInt("_ChunkPerSide", chunksPerSide);
                _spawnOnTileShader.SetBuffer(1, "_SpawnBuffer", _rawSpawnBuffer);
                _spawnOnTileShader.SetBuffer(1, "_ChunkSpawnBuffer", chunkBuffer);
                _spawnOnTileShader.Dispatch(1, Mathf.CeilToInt(totalInstancePerChunk / 128f), 1, 1);
                Bounds b = new Bounds( new Vector3 (botLeft.x + chunkSize* x,0,botLeft.y + chunkSize * y) ,Vector3.one * chunkSize);
                TileChunk t = Chunks[x * chunksPerSide + y] = new TileChunk(
                    _spawnMesh, 
                    _spawnMeshMaterial, 
                    _renderCam, 
                    chunkBuffer, 
                    b,
                    new Vector4(x,y,chunkDimension,chunksPerSide),
                    _tileData
                    );
                t.Init();
            }
        }
    }

    public void DispatchTileChunksDrawCall() 
    {
        Plane[] p= GeometryUtility.CalculateFrustumPlanes(_renderCam);
        foreach (TileChunk t in Chunks)
            if (GeometryUtility.TestPlanesAABB(p, t.ChunkBounds))
                t.Update();
    }

    public void ReleaseBuffer()
    {
        _rawSpawnBuffer?.Dispose();
        foreach (TileChunk t in Chunks)
            t?.ReleaseBuffer();
        _tileClumpParser?.ReleaseBuffer();
    }
}

