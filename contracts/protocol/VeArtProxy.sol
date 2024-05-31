// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {PerlinNoise} from "./art/PerlinNoise.sol";
import {Trig} from "./art/Trig.sol";
import {BokkyPooBahsDateTimeLibrary} from "./art/BokkyPooBahsDateTimeLibrary.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {IVeArtProxy} from "./interfaces/IVeArtProxy.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";

/// @title Protocol ArtProxy
/// @author velodrome.finance, @rncdrncd, @pegahcarter
/// @notice Official art proxy to generate Protocol veNFT artwork
contract VeArtProxy is IVeArtProxy {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint256 private constant PI = 3141592653589793238;
    uint256 private constant TWO_PI = 2 * PI;
    uint256 private constant DASH = 50;
    uint256 private constant DASH_HALF = 25;

    IVotingEscrow public immutable ve;

    /// @dev art palette color codes used in drawing lines
    string[5][10] palettes = [
        ["#F5F3E6", "#DDDBCF", "#C6C5BA", "#B1B0A6", "#9D9B93"], //beije
        ["#FF1100", "#E60F02", "#CF0F04", "#B90E06", "#A40D09"], //red
        ["#9CADFF", "#8D9CE6", "#7E8CCF", "#717DB8", "#646EA3"], //light-blue
        ["#0433FF", "#042EE6", "#0429CF", "#0325B8", "#0221A3"], //blue
        ["#F1ECE2", "#DAD6CE", "#C4C0BC", "#8E8C8E", "#7E7D81"], //silver
        ["#E76F4B", "#D06443", "#BB5A3C", "#A75036", "#944730"], //amber
        ["#FF1100", "#C9D0F2", "#9CADFF", "#0433FF", "#0C0D1D"], //random
        ["#77587A", "#6B506E", "#604763", "#564058", "#4C384E"], //violet
        ["#110E07", "#1B2538", "#020617", "#010513", "#000000"], //black
        ["#B58C8C", "#AC8585", "#9A7777", "#8A6A6A", "#7A5E5E"]
    ]; //pink

    uint8[5] lineThickness = [0, 2, 2, 5, 5];

    constructor(address _ve) {
        ve = IVotingEscrow(_ve);
    }

    /// @inheritdoc IVeArtProxy
    function tokenURI(uint256 _tokenId) external view returns (string memory output) {
        Config memory cfg = generateConfig(_tokenId);
        output = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        "<svg preserveAspectRatio='xMinYMin meet' viewBox='0 0 4000 4000' fill='none' xmlns='http://www.w3.org/2000/svg'>",
                        generateShape(cfg),
                        "</svg>"
                    )
                )
            )
        );

        string memory date;
        if (cfg._lockedEnd == 0) {
            if (cfg._lockedAmount == 0) {
                date = "'Expired'";
            } else {
                date = "'Permanent'";
            }
        } else {
            uint256 year;
            uint256 month;
            uint256 day;
            (year, month, day) = BokkyPooBahsDateTimeLibrary.timestampToDate(uint256(cfg._lockedEnd));
            date = string(abi.encodePacked("'", toString(year), "-", toString(month), "-", toString(day), "'"));
        }

        string memory attributes = string(
            abi.encodePacked("{", "'trait_type': 'Unlock Date',", "'value': ", date, "},")
        );

        // stack too deep
        attributes = string(
            abi.encodePacked(
                attributes,
                "{",
                "'trait_type': 'Voting Power',",
                "'value': ",
                toString(cfg._balanceOf / 1e18),
                "},",
                "{",
                "'trait_type': 'Locked MONI',"
                '"value": ',
                toString(cfg._lockedAmount / 1e18),
                "},"
                "{",
                "'display_type': 'number',",
                "'trait_type': 'Number of Digits',",
                '"value": ',
                toString(numBalanceDigits(uint256(cfg._balanceOf))),
                "}"
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        "{",
                        "'name': 'lock #",
                        toString(cfg._tokenId),
                        "',",
                        "'background_color': '121a26',",
                        "'description': 'Moniswap is a next-generation AMM inspired by Aerodrome, and designed to serve as the Berachain central liquidity hub.',",
                        "'image_data': 'data:image/svg+xml;base64,",
                        output,
                        "',",
                        "'attributes': [",
                        attributes,
                        "]",
                        "}"
                    )
                )
            )
        );

        output = string(abi.encodePacked("data:application/json;base64,", json));
    }

    /// @inheritdoc IVeArtProxy
    function lineArtPathsOnly(uint256 _tokenId) external view returns (bytes memory output) {
        Config memory cfg = generateConfig(_tokenId);
        output = abi.encodePacked(generateShape(cfg));
    }

    /// @inheritdoc IVeArtProxy
    function generateConfig(uint256 _tokenId) public view returns (Config memory cfg) {
        cfg._tokenId = int256(_tokenId);
        cfg._balanceOf = int256(ve.balanceOfNFTAt(_tokenId, block.timestamp));
        IVotingEscrow.LockedBalance memory _locked = ve.locked(_tokenId);
        cfg._lockedEnd = int256(_locked.end);
        cfg._lockedAmount = int256(_locked.amount);

        cfg.shape = seedGen(_tokenId) % 8;
        cfg.palette = getPalette(_tokenId);
        cfg.maxLines = getLineCount(uint256(cfg._balanceOf));

        cfg.seed1 = seedGen(_tokenId);
        cfg.seed2 = seedGen(_tokenId * 1e18);
        cfg.seed3 = seedGen(_tokenId * 2e18);
    }

    /// @dev Generates characteristics for each line in the line art.
    function generateLineConfig(Config memory cfg, int256 l) internal view returns (LineConfig memory linecfg) {
        uint256 x = uint256(l);
        linecfg.color = palettes[cfg.palette][
            uint256(keccak256(abi.encodePacked((l + 20) * (cfg._lockedEnd + cfg._tokenId)))) % 5
        ];
        linecfg.stroke = uint256(keccak256(abi.encodePacked((l + 1) * (cfg._lockedEnd + cfg._tokenId)))) % 5;
        linecfg.offset =
            ((uint256(keccak256(abi.encodePacked((l + 1) * (cfg._lockedEnd + cfg._tokenId)))) % 50) / 2) *
            2 *
            5; // ensure value is even
        linecfg.offsetHalf = (linecfg.offset / 2) * 5;
        linecfg.offsetDashSum = linecfg.offset + DASH + linecfg.offsetHalf + DASH_HALF;
        if ((uint256(cfg.seed2) / (1 + x)) % 6 != 0) {
            linecfg.pathLength = linecfg.offsetDashSum * (10 + ((uint256(cfg.seed1 * cfg.seed3) / (1 + x * x)) % 15));
        }
    }

    /// @dev Selects and draws line art shape.
    function generateShape(Config memory cfg) internal view returns (bytes memory shape) {
        if (cfg.shape == 0) {
            shape = drawCircles(cfg);
        } else if (cfg.shape == 1) {
            shape = drawTwoStripes(cfg);
        } else if (cfg.shape == 2) {
            shape = drawInterlockingCircles(cfg);
        } else if (cfg.shape == 3) {
            shape = drawCorners(cfg);
        } else if (cfg.shape == 4) {
            shape = drawCurves(cfg);
        } else if (cfg.shape == 5) {
            shape = drawSpiral(cfg);
        } else if (cfg.shape == 6) {
            shape = drawExplosion(cfg);
        } else {
            shape = drawWormhole(cfg);
        }
    }

    /// @dev Calculates the number of digits before the "decimal point" in an NFT's veAERO balance.
    ///      Input expressed in 1e18 format.
    function numBalanceDigits(uint256 _balanceOf) internal pure returns (int256 digitCount) {
        uint256 convertedveAEROvalue = _balanceOf / 1e18;
        while (convertedveAEROvalue != 0) {
            convertedveAEROvalue /= 10;
            digitCount++;
        }
    }

    /// @dev Generates a pseudorandom seed based on a veNFT token ID.
    function seedGen(uint256 _tokenId) internal pure returns (int256 seed) {
        seed = 1 + int256(uint256(keccak256(abi.encodePacked(_tokenId))) % 999);
    }

    /// @dev Determines the number of lines in the SVG. NFTs with less than 10 veAERO balance have zero lines.
    function getLineCount(uint256 _balanceOf) internal pure returns (int256 lineCount) {
        int256 threshold = 2;
        int256 balDigits = numBalanceDigits(_balanceOf);
        lineCount = 2 * balDigits;
        if (balDigits < threshold) {
            lineCount = 0;
        }
    }

    /// @dev Determines the color palette of the SVG.
    function getPalette(uint256 _tokenId) internal pure returns (uint256 palette) {
        palette = uint256(keccak256(abi.encodePacked(_tokenId))) % 10;
    }

    /*---
    Line Art Generation
    ---*/

    function drawTwoStripes(Config memory cfg) internal view returns (bytes memory shape) {
        for (int256 l = 0; l < cfg.maxLines; l++) {
            Point[100] memory Line = twoStripes(cfg, l);
            shape = abi.encodePacked(shape, curveToSVG(l, cfg, Line));
        }
    }

    /// @inheritdoc IVeArtProxy
    function twoStripes(Config memory cfg, int256 l) public pure returns (Point[100] memory Line) {
        int256 k = ((l % 2) *
            ((200 + cfg.seed3) + ((l * 1250) / cfg.maxLines)) +
            ((l + 1) % 2) *
            ((2200 + cfg.seed2) + ((l * 1250) / cfg.maxLines)));
        int256 i1 = cfg.seed1 % 2;
        int256 i2 = (cfg.seed1 + 1) % 2;
        int256 o1 = i1 * k;
        int256 o2 = i2 * k;

        for (int256 p = 0; p < 100; p++) {
            Line[uint256(p)] = Point({x: 41 * p * i2 + o1, y: 41 * p * i1 + o2});
        }
    }

    function drawCircles(Config memory cfg) internal view returns (bytes memory shape) {
        for (int256 l = 0; l < cfg.maxLines; l++) {
            Point[100] memory Line = circles(cfg, l);
            shape = abi.encodePacked(shape, curveToSVG(l, cfg, Line));
        }
    }

    /// @inheritdoc IVeArtProxy
    function circles(Config memory cfg, int256 l) public pure returns (Point[100] memory Line) {
        int256 baseX = 500 + ((cfg.seed1 % 100) * 30);
        int256 baseY = 500 + ((cfg.seed2 % 100) * 30);
        int256 k = (cfg.seed3 % 250) + 250 + 100 * (1 + l);
        int256 i = (l % 2) * 2 - 1;

        for (uint256 p = 0; p < 100; p++) {
            uint256 angle = (1e18 * TWO_PI * p) / 99;
            Line[p] = Point({x: baseX + (k * Trig.sin(angle)) / 1e18, y: baseY + (i * k * Trig.cos(angle)) / 1e18});
        }
    }

    function drawInterlockingCircles(Config memory cfg) internal view returns (bytes memory shape) {
        for (int256 l = 0; l < cfg.maxLines; l++) {
            Point[100] memory Line = interlockingCircles(cfg, l);
            shape = abi.encodePacked(shape, curveToSVG(l, cfg, Line));
        }
    }

    /// @inheritdoc IVeArtProxy
    function interlockingCircles(Config memory cfg, int256 l) public pure returns (Point[100] memory Line) {
        int256 baseX = (1500 + cfg.seed1) + ((l * 100) * Trig.dcos(90 * l)) / 1e6;
        int256 baseY = (1500 + cfg.seed2) + ((l * 100) * Trig.dsin(90 * l)) / 1e6;
        int256 k = (l + 1) * 100;

        for (uint256 p = 0; p < 100; p++) {
            uint256 angle = (1e18 * TWO_PI * p) / 99;
            Line[p] = Point({x: baseX + (k * Trig.cos(angle)) / 1e18, y: baseY + (k * Trig.sin(angle)) / 1e18});
        }
    }

    function drawCorners(Config memory cfg) internal view returns (bytes memory shape) {
        for (int256 l = 0; l < cfg.maxLines; l++) {
            Point[100] memory Line = corners(cfg, l);
            shape = abi.encodePacked(shape, curveToSVG(l, cfg, Line));
        }
    }

    /// @inheritdoc IVeArtProxy
    function corners(Config memory cfg, int256 l) public pure returns (Point[100] memory Line) {
        int256 degrees1 = (360 * cfg.seed1) / 1000;
        int256 degrees2 = (360 * (cfg.seed1 + 500)) / 1000;
        int256 baseX = 2000 +
            (((l % 2) * 1200 * Trig.dcos(degrees1)) / 1e6) +
            ((((l + 1) % 2) * (1200 * Trig.dcos(degrees2))) / 1e6);
        int256 baseY = 2000 +
            (((l % 2) * 1200 * Trig.dsin(degrees1)) / 1e6) +
            ((((l + 1) % 2) * (1200 * Trig.dsin(degrees2))) / 1e6);
        int256 k = 100 + ((1 + l) * 4000) / cfg.maxLines / 4;

        for (int256 p = 0; p < 100; p++) {
            int256 angle3 = (360 * l) / cfg.maxLines + ((360 * p) / 99);
            Line[uint256(p)] = Point({
                x: baseX + (k * Trig.dcos(angle3)) / 1e6,
                y: baseY + (((l % 2) * 2 - 1) * k * Trig.dsin(angle3)) / 1e6
            });
        }
    }

    function drawCurves(Config memory cfg) internal view returns (bytes memory shape) {
        for (int256 l = 0; l < cfg.maxLines; l++) {
            Point[100] memory Line = curves(cfg, l);
            shape = abi.encodePacked(shape, curveToSVG(l, cfg, Line));
        }
    }

    /// @inheritdoc IVeArtProxy
    function curves(Config memory cfg, int256 l) public pure returns (Point[100] memory Line) {
        int256 x = (l * 65536) / 150;
        int256 z = cfg.seed1 * 65536;
        int256 k1 = (cfg.seed1 + 1) % 2;
        int256 k2 = cfg.seed1 % 2;
        int256 kA2 = -100 + (4200 * l) / cfg.maxLines;

        for (int256 p = 0; p < 100; p++) {
            int256 _sin = Trig.sin((1e18 * TWO_PI * uint256(p)) / 99);
            int256 noise = PerlinNoise.noise3d(x, (p * 65536) / 2000, z);
            int256 a1 = (-100 + (4200 * p) / 99) + (_sin * noise * 1700) / 65536 / 1e18;
            int256 a2 = kA2 + (_sin * noise * 15000) / 65536 / 1e18;

            Line[uint256(p)] = Point({x: k1 * a1 + k2 * a2, y: k1 * a2 + k2 * a1});
        }
    }

    function drawSpiral(Config memory cfg) internal view returns (bytes memory shape) {
        for (int256 l = 0; l < cfg.maxLines; l++) {
            Point[100] memory Line = spiral(cfg, l);
            shape = abi.encodePacked(shape, curveToSVG(l, cfg, Line));
        }
    }

    /// @inheritdoc IVeArtProxy
    function spiral(Config memory cfg, int256 l) public pure returns (Point[100] memory Line) {
        int256 baseX = 500 + ((cfg.seed1 % 100) * 30);
        int256 baseY = 500 + ((cfg.seed2 % 100) * 30);
        int256 degrees1 = (360 * l) / cfg.maxLines;
        int256 cosine = Trig.dcos(degrees1);
        int256 sine = Trig.dsin(degrees1);

        for (int256 p = 0; p < 100; p++) {
            int256 degrees2 = degrees1 + 3 * p;
            Line[uint256(p)] = Point({
                x: baseX + ((325 * cosine) / 1e6) + ((40 * p) * Trig.dcos(degrees2)) / 1e6,
                y: baseY + ((325 * sine) / 1e6) + ((40 * p) * Trig.dsin(degrees2)) / 1e6
            });
        }
    }

    function drawExplosion(Config memory cfg) internal view returns (bytes memory shape) {
        for (int256 l = 0; l < cfg.maxLines; l++) {
            Point[100] memory Line = explosion(cfg, l);
            shape = abi.encodePacked(shape, curveToSVG(l, cfg, Line));
        }
    }

    /// @inheritdoc IVeArtProxy
    function explosion(Config memory cfg, int256 l) public pure returns (Point[100] memory Line) {
        int256 baseX = 1000 + ((cfg.seed1 % 100) * 20);
        int256 baseY = 1000 + ((cfg.seed2 % 100) * 20);
        int256 degrees = (360 * l) / cfg.maxLines;
        int256 k = 300 + ((cfg.seed3 * (l + 1)**2) % 300);
        int256 cosine = Trig.dcos(degrees);
        int256 sine = Trig.dsin(degrees);

        for (int256 p = 0; p < 100; p++) {
            Line[99 - uint256(p)] = Point({
                x: baseX + (k * cosine) / 1e6 + (((4000 * p) / 99) * cosine) / 1e6,
                y: baseY + (k * sine) / 1e6 + (((4000 * p) / 99) * sine) / 1e6
            });
        }
    }

    function drawWormhole(Config memory cfg) internal view returns (bytes memory shape) {
        for (int256 l = 0; l < cfg.maxLines; l++) {
            Point[100] memory Line = wormhole(cfg, l);
            shape = abi.encodePacked(shape, curveToSVG(l, cfg, Line));
        }
    }

    /// @inheritdoc IVeArtProxy
    function wormhole(Config memory cfg, int256 l) public pure returns (Point[100] memory Line) {
        int256 baseX = 500 + (cfg.seed1 * 3);
        int256 baseY = 500 + (cfg.seed2 * 3);
        int256 degrees = (360 * l) / cfg.maxLines;
        int256 cosine = Trig.dcos(degrees);
        int256 sine = Trig.dsin(degrees);
        int256 k1 = 3500 - cfg.seed1 * 3;
        int256 k2 = 3500 - cfg.seed2 * 3;

        for (int256 p = 0; p < 100; p++) {
            Line[uint256(p)] = Point({
                x: (baseX * (99 - p)) /
                    99 +
                    (250 * cosine) /
                    1e6 +
                    (cosine * ((5000 * p) / 99) * (99 - p)) /
                    99 /
                    1e6 +
                    (p * k1) /
                    99,
                y: (baseY * (99 - p)) /
                    99 +
                    (250 * sine) /
                    1e6 +
                    (sine * ((5000 * p) / 99) * (99 - p)) /
                    99 /
                    1e6 +
                    (p * k2) /
                    99
            });
        }
    }

    /*---
    SVG Formatting
    ---*/

    /// @dev Converts an array of Point structs into an animated SVG path.
    function curveToSVG(
        int256 l,
        Config memory cfg,
        Point[100] memory Line
    ) internal view returns (bytes memory SVGLine) {
        string memory lineBulk;
        bool priorPointOutOfCanvas = false;
        for (uint256 i = 1; i < Line.length; i++) {
            (int256 x, int256 y) = (Line[i].x, Line[i].y);
            if (x > -200 && x < 4200 && y > -200 && y < 4200) {
                if (priorPointOutOfCanvas) {
                    lineBulk = string.concat(lineBulk, "M", toString(x), ",", toString(y));
                    priorPointOutOfCanvas = false;
                } else {
                    lineBulk = string.concat(lineBulk, "L", toString(x), ",", toString(y));
                    priorPointOutOfCanvas = false;
                }
            } else {
                priorPointOutOfCanvas = true;
            }
        }

        LineConfig memory linecfg = generateLineConfig(cfg, l);
        {
            SVGLine = abi.encodePacked(
                "<path d='M",
                toString(Line[0].x),
                ",",
                toString(Line[0].y),
                lineBulk,
                "'",
                " style='stroke-dasharray: ",
                toString(linecfg.offset),
                ",",
                toString(DASH),
                ",",
                toString(linecfg.offsetHalf),
                ",",
                toString(DASH_HALF),
                ";",
                " --offset: "
            );
        }

        {
            SVGLine = abi.encodePacked(
                SVGLine,
                toString(linecfg.offsetDashSum),
                ";",
                " stroke: ",
                linecfg.color,
                ";",
                " stroke-width: 0.",
                toString(lineThickness[linecfg.stroke]),
                "%",
                ";' pathLength='",
                toString(linecfg.pathLength),
                "'>",
                "<animate attributeName='stroke-dashoffset' values='0;",
                toString(linecfg.offsetDashSum),
                "' ",
                "dur='4s' calcMode='linear' repeatCount='indefinite' /></path>"
            );
        }
    }

    /*---
    OpenZeppelin Functions
    ---*/

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(abs(value))));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }
}