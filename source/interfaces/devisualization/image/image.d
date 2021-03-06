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
module devisualization.image.image;
import devisualization.image.color;
import std.range : InputRange;

interface Image {
    //this(Image from);

    @property {
        ImagePixels!Color_RGBA rgba();

        size_t width();
        size_t height();
    }

    ubyte[] exportFrom();
    void exportTo(string file);
}


interface ImagePixels(COLOR) : InputRange!COLOR {
    @property COLOR[] allPixels();
    COLOR opIndex(size_t idx);
    void opIndexAssign(COLOR, size_t idx);
    @property size_t length();

    size_t xFromIndex(size_t idx);
    size_t yFromIndex(size_t idx);

    size_t indexFromXY(size_t x, size_t y);
}

alias NotAnImageException = Exception;