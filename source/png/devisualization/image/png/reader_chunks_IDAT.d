﻿/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2014 Devisualization (Richard Andrew Cattermole)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
module devisualization.image.png.reader_chunks_IDAT;
import devisualization.image.png.defs;
import devisualization.image.png.chunks;
import devisualization.image;

void handle_IDAT_chunk(PngImage _, ubyte[] chunkData) {
    with(_) {
        ubyte[] pixelData;
        size_t colorSize;

        if (IHDR.compressionMethod == PngIHDRCompresion.DeflateInflate) {
            size_t expectedSize;

            if (IHDR.compressionMethod == PngIHDRCompresion.DeflateInflate) {
                decompressInflateDeflate(_, chunkData,
                                        pixelData, expectedSize, colorSize);
            } else {
                throw new NotAnImageException("Unknown compression method");
            }
        } else {
            throw new NotAnImageException("Invalid image compression method");
        }

        ubyte[] adaptiveOffsets;
        ubyte[][] rawPixelData = grabPixelsRawData(_, pixelData, adaptiveOffsets, colorSize);
        
        if (IHDR.filterMethod == PngIHDRFilter.Adaptive) {
            IDAT.unfiltered_uncompressed_pixels = adaptivePixelGrabber(_, rawPixelData, adaptiveOffsets, colorSize);
        } else {
            throw new NotAnImageException("Invalid image filter method");
        }

        if (IHDR.interlaceMethod == PngIHDRInterlaceMethod.Adam7) {
            // TODO: un Adam7 algo IDAT.unfiltered_uncompressed_pixels
        } else if (IHDR.interlaceMethod == PngIHDRInterlaceMethod.NoInterlace) {
        } else {
            throw new NotAnImageException("Invalid image filter method");
        }

        // TODO: turn IDAT.unfiltered_uncompressed_pixels into something usable
        foreach(pixel; IDAT.unfiltered_uncompressed_pixels) {
            if (pixel.used_color) {
                if (IHDR.bitDepth == PngIHDRBitDepth.BitDepth16) {
                    allMyPixels ~= new Color_RGBA(pixel.r, pixel.g, pixel.b, pixel.a);
                } else if (IHDR.bitDepth == PngIHDRBitDepth.BitDepth8) {
                    allMyPixels ~= new Color_RGBA(cast(ushort)(pixel.r * ubyteToUshort),
                                                  cast(ushort)(pixel.g * ubyteToUshort),
                                                  cast(ushort)(pixel.b * ubyteToUshort),
                                                  cast(ushort)(pixel.a * ubyteToUshort));
                }
            } else {
                // TODO: e.g. grayscale, palleted
            }
        }
    }
}

void decompressInflateDeflate(PngImage _, ubyte[] chunkData,
out ubyte[] uncompressed, out size_t expectedSize, out size_t colorSize) {
    import std.zlib : uncompress;

    with(_) {
        if (IHDR.filterMethod == PngIHDRFilter.Adaptive) {
            // add one per scan line
            expectedSize = IHDR.height;
        }
        
        if (IHDR.colorType == PngIHDRColorType.Palette) {
            colorSize = 1;
        } else if (IHDR.colorType == PngIHDRColorType.PalletteWithColorUsed) {
            colorSize = 2;
        } else if (IHDR.colorType == PngIHDRColorType.ColorUsed) {
            colorSize = 3;
        } else if (IHDR.colorType == PngIHDRColorType.ColorUsedWithAlpha) {
            colorSize = 4;
        }

        switch(IHDR.bitDepth) {
            case PngIHDRBitDepth.BitDepth8:
            case PngIHDRBitDepth.BitDepth4:
            case PngIHDRBitDepth.BitDepth2:
            case PngIHDRBitDepth.BitDepth1:
                expectedSize += colorSize;
                break;
                
            case PngIHDRBitDepth.BitDepth16:
                colorSize *= 2;
                expectedSize += colorSize;
                break;
                
            default:
                throw new NotAnImageException("Unknown bit depth");
        }
    }

    uncompressed = cast(ubyte[])uncompress(chunkData, expectedSize);
}

ubyte[][] grabPixelsRawData(PngImage _, ubyte[] rawData, ref ubyte[] adaptiveOffsets, size_t colorSize) {
    ubyte[][] ret;

    with(_) {
        size_t sinceLast = IHDR.width - 1;
        size_t i;

        while(i < rawData.length) {
            if (IHDR.filterMethod == PngIHDRFilter.Adaptive) {
                if (sinceLast == IHDR.width - 1) {
                    // finished a scan line
                    adaptiveOffsets ~= rawData[i];
                    sinceLast = 0;
                    i++;
                } else {
                    sinceLast++;
                }

                ret ~= rawData[i .. i + colorSize];

                i += colorSize;
            } // else if ...
        }
    }

    return ret;
}

IDAT_Chunk_Pixel[] adaptivePixelGrabber(PngImage _, ubyte[][] data, ubyte[] filters, size_t colorSize) {
    size_t scanLine = 0;
    IDAT_Chunk_Pixel[] pixels;

    with(_) {
        foreach(pixel, pixelData; data) {
            ubyte[] lastPixelData;
            if (pixel > 0)
                lastPixelData = data[pixel - 1];
            else
                lastPixelData.length = pixelData.length;

            for(size_t i = 0; i < pixelData.length -1; i += colorSize) {
                ubyte[] thePixel = pixelData.dup;

                // unfilter
                switch(filters[scanLine]) {
                    case 1: // sub
                        // Sub(x) + Raw(x-bpp)
                        
                        foreach(j; 0 .. colorSize) {
                            thePixel[j] = pixelData[j];
                        }
                        
                        foreach(j; colorSize .. pixelData.length) {
                            thePixel[j] = cast(ubyte)(pixelData[j] + pixelData[j - colorSize]);
                        }
                        break;
                        
                    case 2: // up
                        // Up(x) + Prior(x)
                        
                        if (i > 0) {
                            thePixel[0] = pixelData[0];
                            foreach(j; 1 .. pixelData.length) {
                                thePixel[j] = cast(ubyte)(pixelData[j] + lastPixelData[j]);
                            }
                        } else {
                            thePixel = pixelData;
                        }
                        break;
                        
                    case 3: // average
                        import std.math : floor;
                        // Average(x) + floor((Raw(x-bpp)+Prior(x))/2)
                        
                        foreach(j; 0 .. colorSize) {
                            ubyte prior = i > 0 ? lastPixelData[j - 1] : 0;
                            
                            thePixel[j] = cast(ubyte)(pixelData[j] + cast(ubyte)floor(cast(real)(0 + prior) / 2));
                        }
                        
                        foreach(j; colorSize .. pixelData.length) {
                            thePixel[j] = cast(ubyte)(pixelData[j] + cast(ubyte)floor(cast(real)(pixelData[j - colorSize] + lastPixelData[j - 1]) / 2));
                        }
                        break;
                        
                    case 4: // paeth
                        //  Paeth(x) + PaethPredictor(Raw(x-bpp), Prior(x), Prior(x-bpp))
                        
                        foreach(j; 0 .. colorSize) {
                            ubyte priorAbove = i > 0 ? lastPixelData[j] : 0;
                            ubyte priorAboveLeft = i > 0 ? lastPixelData[j - colorSize] : 0;
                            
                            thePixel[j] = cast(ubyte)(pixelData[j] + PaethPredictor(0, priorAbove, priorAboveLeft));
                        }
                        
                        foreach(j; colorSize .. pixelData.length) {
                            thePixel[j] = cast(ubyte)(pixelData[j] + PaethPredictor(pixelData[j - colorSize], lastPixelData[j], lastPixelData[j - colorSize]));
                        }
                        
                        break;
                        
                    default:
                    case 0: // none
                        break;
                }

                pixels ~= new IDAT_Chunk_Pixel(thePixel, IHDR.bitDepth == PngIHDRBitDepth.BitDepth16);

                if (i % IHDR.width == IHDR.width-1) {
                    scanLine++;
                }
            }
        }
    }

    return pixels;
}

ubyte PaethPredictor(ubyte a, ubyte b, ubyte c) {
    import std.math : abs;

    // a = left, b = above, c = upper left
    int p = a + b - c;        // initial estimate
    int pa = abs(p - a);      // distances to a, b, c
    int pb = abs(p - b);
    int pc = abs(p - c);

    // return nearest of a,b,c,
    // breaking ties in order a,b,c.
    if (pa <= pb && pa <= pc) return a;
    else if (pb <= pc) return b;
    else return c;
}