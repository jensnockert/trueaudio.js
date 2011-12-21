class TTADemuxer extends Demuxer
    Demuxer.register(TTADemuxer)
    
    @probe: (buffer) ->
        return buffer.peekString(0, 4) is 'TTA1'
        
    readChunk: ->
        if not @readHeader and @stream.available(22)
            if @stream.readString(4) isnt 'TTA1'
                return @emit 'error', 'Invalid TTA file.'
            
            @flags = @stream.readUInt16(true) # little endian
            @format = 
                formatID: 'tta'
                channelsPerFrame: @stream.readUInt16(true)
                bitsPerChannel: @stream.readUInt16(true)
                sampleRate: @stream.readUInt32(true)
                sampleCount: @stream.readUInt32(true)
            
            @emit 'format', @format
            @emit 'duration', @format.sampleCount / @format.sampleRate * 1000 | 0
            
            @stream.advance(4) # skip CRC32 footer
            @readHeader = true
        
        if @readHeader and not @readSeekTable
            framelen = @format.sampleRate * 256 / 245
            datalen = @format.sampleCount
            totalFrames = datalen / framelen + ((datalen % framelen) ? 1 : 0)
            seekTableSize = totalFrames * 4 | 0
            
            return unless @stream.available(seekTableSize + 4)
            
            @stream.advance(seekTableSize)
            @stream.advance(4) # seektable csc
            
            @readSeekTable = true
            
        if @readSeekTable
            @emit 'data', @stream.readSingleBuffer(@stream.list.availableBytes - @stream.localOffset)
            
        return